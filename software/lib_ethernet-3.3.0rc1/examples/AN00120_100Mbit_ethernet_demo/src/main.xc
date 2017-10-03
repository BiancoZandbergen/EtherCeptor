// Copyright (c) 2014-2016, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <platform.h>
#include "otp_board_info.h"
#include "ethernet.h"
#include "icmp.h"
#include "smi.h"

port eth1_p_eth_rxclk  = on tile[0]: XS1_PORT_1I;
port eth1_p_eth_rxd    = on tile[0]: XS1_PORT_4D;
port eth1_p_eth_txd    = on tile[0]: XS1_PORT_4C;
port eth1_p_eth_rxdv   = on tile[0]: XS1_PORT_1H;
port eth1_p_eth_txen   = on tile[0]: XS1_PORT_1E;
port eth1_p_eth_txclk  = on tile[0]: XS1_PORT_1F;
port eth1_p_eth_rxerr  = on tile[0]: XS1_PORT_1G;
port eth1_p_eth_dummy  = on tile[0]: XS1_PORT_8B;
clock eth1_eth_rxclk   = on tile[0]: XS1_CLKBLK_1;
clock eth1_eth_txclk   = on tile[0]: XS1_CLKBLK_2;
port eth1_p_smi_mdio   = on tile[0]: XS1_PORT_1K;
port eth1_p_smi_mdc    = on tile[0]: XS1_PORT_1J;
on tile[0]: out port t0_p_led = XS1_PORT_1M;
//otp_ports_t eth1_otp_ports = on tile[0]: OTP_PORTS_INITIALIZER;

port eth2_p_eth_rxclk  = on tile[1]: XS1_PORT_1M;
port eth2_p_eth_rxd    = on tile[1]: XS1_PORT_4F;
port eth2_p_eth_txd    = on tile[1]: XS1_PORT_4E;
port eth2_p_eth_rxdv   = on tile[1]: XS1_PORT_1L;
port eth2_p_eth_txen   = on tile[1]: XS1_PORT_1B;
port eth2_p_eth_txclk  = on tile[1]: XS1_PORT_1C;
port eth2_p_eth_rxerr  = on tile[1]: XS1_PORT_1D;
port eth2_p_eth_dummy  = on tile[1]: XS1_PORT_8C;
clock eth2_eth_rxclk   = on tile[1]: XS1_CLKBLK_1;
clock eth2_eth_txclk   = on tile[1]: XS1_CLKBLK_2;
port eth2_p_smi_mdio   = on tile[1]: XS1_PORT_1O;
port eth2_p_smi_mdc    = on tile[1]: XS1_PORT_1N;
on tile[1]: out port t1_p_led = XS1_PORT_1A;
//otp_ports_t eth2_otp_ports = on tile[1]: OTP_PORTS_INITIALIZER;

static unsigned char eth1_ip_address[4] = {10, 0, 0, 3};
static unsigned char eth2_ip_address[4] = {10, 0, 0, 4};

static unsigned char eth1_mac_address[6] = {0x11,0x22, 0x33, 0x44, 0x55, 0x66};
static unsigned char eth2_mac_address[6] = {0x22, 0x33, 0x44, 0x55, 0x66, 0x77};

// An enum to manage the array of connections from the ethernet component
// to its clients.
enum eth_clients {
  ETH_TO_ICMP,
  NUM_ETH_CLIENTS
};

enum cfg_clients {
  CFG_TO_ICMP,
  CFG_TO_PHY_DRIVER,
  NUM_CFG_CLIENTS
};

[[combinable]]
void lan8710a_phy_driver(client interface smi_if smi,
                         client interface ethernet_cfg_if eth) {
  ethernet_link_state_t link_state = ETHERNET_LINK_DOWN;
  ethernet_speed_t link_speed = LINK_100_MBPS_FULL_DUPLEX;
  const int link_poll_period_ms = 1000;
  const int phy_address = 0x01;
  timer tmr;
  int t;
  tmr :> t;

  while (smi_phy_is_powered_down(smi, phy_address));
  smi_configure(smi, phy_address, LINK_100_MBPS_FULL_DUPLEX, SMI_ENABLE_AUTONEG);

  while (1) {
    select {
    case tmr when timerafter(t) :> t:
      ethernet_link_state_t new_state = smi_get_link_state(smi, phy_address);
      // Read LAN8710A status register bit 2 to get the current link speed
      if ((new_state == ETHERNET_LINK_UP) &&
         ((smi.read_reg(phy_address, 0x1F) >> 2) & 1)) {
        link_speed = LINK_10_MBPS_FULL_DUPLEX;
      }
      else {
        link_speed = LINK_100_MBPS_FULL_DUPLEX;
      }
      if (new_state != link_state) {
        link_state = new_state;
        eth.set_link_state(0, new_state, link_speed);
      }
      t += link_poll_period_ms * XS1_TIMER_KHZ;
      break;
    }
  }
}

#define DELAY_HZ 50000000
void t0_flash_led()
{
  timer t;
  unsigned time;

  while (1) {
    t0_p_led <: 1;
    t :> time;
    time += DELAY_HZ;
    t when timerafter(time) :> void;

    t0_p_led <: 0;
    t :> time;
    time += DELAY_HZ;
    t when timerafter(time) :> void;
  }
}

void t1_flash_led()
{
  timer t;
  unsigned time;

  while (1) {
    t1_p_led <: 1;
    t :> time;
    time += DELAY_HZ;
    t when timerafter(time) :> void;

    t1_p_led <: 0;
    t :> time;
    time += DELAY_HZ;
    t when timerafter(time) :> void;
  }
}

#define ETH_RX_BUFFER_SIZE_WORDS 1600

int main()
{
  ethernet_cfg_if eth1_i_cfg[NUM_CFG_CLIENTS];
  ethernet_rx_if eth1_i_rx[NUM_ETH_CLIENTS];
  ethernet_tx_if eth1_i_tx[NUM_ETH_CLIENTS];
  smi_if eth1_i_smi;

  ethernet_cfg_if eth2_i_cfg[NUM_CFG_CLIENTS];
  ethernet_rx_if eth2_i_rx[NUM_ETH_CLIENTS];
  ethernet_tx_if eth2_i_tx[NUM_ETH_CLIENTS];
  smi_if eth2_i_smi;

  par {
    on tile[0]: mii_ethernet_mac(eth1_i_cfg, NUM_CFG_CLIENTS,
                                 eth1_i_rx, NUM_ETH_CLIENTS,
                                 eth1_i_tx, NUM_ETH_CLIENTS,
                                 eth1_p_eth_rxclk, eth1_p_eth_rxerr,
                                 eth1_p_eth_rxd, eth1_p_eth_rxdv,
                                 eth1_p_eth_txclk, eth1_p_eth_txen, eth1_p_eth_txd,
                                 eth1_p_eth_dummy,
                                 eth1_eth_rxclk, eth1_eth_txclk,
                                 ETH_RX_BUFFER_SIZE_WORDS);

    on tile[0]: lan8710a_phy_driver(eth1_i_smi, eth1_i_cfg[CFG_TO_PHY_DRIVER]);

    on tile[0]: smi(eth1_i_smi, eth1_p_smi_mdio, eth1_p_smi_mdc);

    on tile[0]: icmp_server(eth1_i_cfg[CFG_TO_ICMP],
                            eth1_i_rx[ETH_TO_ICMP], eth2_i_tx[ETH_TO_ICMP],
                            eth1_ip_address, eth1_mac_address);

    on tile[0] : t0_flash_led();

    on tile[1]: mii_ethernet_mac(eth2_i_cfg, NUM_CFG_CLIENTS,
                                 eth2_i_rx, NUM_ETH_CLIENTS,
                                 eth2_i_tx, NUM_ETH_CLIENTS,
                                 eth2_p_eth_rxclk, eth2_p_eth_rxerr,
                                 eth2_p_eth_rxd, eth2_p_eth_rxdv,
                                 eth2_p_eth_txclk, eth2_p_eth_txen, eth2_p_eth_txd,
                                 eth2_p_eth_dummy,
                                 eth2_eth_rxclk, eth2_eth_txclk,
                                 ETH_RX_BUFFER_SIZE_WORDS);

    on tile[1]: lan8710a_phy_driver(eth2_i_smi, eth2_i_cfg[CFG_TO_PHY_DRIVER]);

    on tile[1]: smi(eth2_i_smi, eth2_p_smi_mdio, eth2_p_smi_mdc);

    on tile[1]: icmp_server(eth2_i_cfg[CFG_TO_ICMP],
                            eth2_i_rx[ETH_TO_ICMP], eth1_i_tx[ETH_TO_ICMP],
                            eth2_ip_address, eth2_mac_address);

    on tile[1] : t1_flash_led();
  }
  return 0;
}
