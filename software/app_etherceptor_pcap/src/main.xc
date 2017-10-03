/* ETH1 - ETH2 forwarding mode, i.e. act like a wire */

#include <xs1.h>
#include <platform.h>
#include "ethernet.h"
#include "smi.h"
#include <led.h>
#include <uart.h>
#include <print.h>
#include "serial.h"
#include "packet.h"
#include "stats.h"
#include "pcap.h"

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
out port t0_p_led      = on tile[0]: XS1_PORT_1M;

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
out port t1_p_led      = on tile[1]: XS1_PORT_1A;

port p_uart_rx         = on tile[0] : XS1_PORT_1P;
port p_uart_tx         = on tile[0] : XS1_PORT_1O;

port p_button          = on tile[0] : XS1_PORT_1N;

#define BAUD_RATE 115200
#define RX_BUFFER_SIZE 64

// An enum to manage the array of connections from the ethernet component
// to its clients.
enum eth_clients {
  ETH_TO_PACKET_HANDLER,
  NUM_ETH_CLIENTS
};

enum cfg_clients {
  CFG_TO_PACKET_HANDLER,
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


#define ETH_RX_BUFFER_SIZE_WORDS 16000

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

  interface led_if led_if0, led_if1;
  interface stats_if stats_if[2];
  interface pcap_if pcap_if[3];

  interface uart_rx_if i_rx;
  interface uart_tx_buffered_if i_tx;
  input_gpio_if i_gpio_rx;
  output_gpio_if i_gpio_tx[1];

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

    on tile[0]: packet_handler(eth1_i_cfg[CFG_TO_PACKET_HANDLER],
                            eth1_i_rx[ETH_TO_PACKET_HANDLER], eth2_i_tx[ETH_TO_PACKET_HANDLER],
                            led_if0, stats_if[0], pcap_if[0], p_button);

    on tile[0].core[1]: led_handler(t0_p_led, led_if0);
    on tile[0].core[1]: serial_handler(i_tx, i_rx, stats_if, pcap_if[2]);
    on tile[0]: pcap_handler(pcap_if);

    on tile[0]: output_gpio(i_gpio_tx, 1, p_uart_tx, null);
    on tile[0]: uart_tx_buffered(i_tx, null, UART_TX_BUF_SIZE,
                         BAUD_RATE, UART_PARITY_NONE, 8, 1,
                        i_gpio_tx[0]);
    on tile[0].core[0]: input_gpio_1bit_with_events(i_gpio_rx, p_uart_rx);
    on tile[0].core[0]: uart_rx(i_rx, null, RX_BUFFER_SIZE,
                                BAUD_RATE, UART_PARITY_NONE, 8, 1,
                                i_gpio_rx);

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

    on tile[1]: packet_handler(eth2_i_cfg[CFG_TO_PACKET_HANDLER],
                            eth2_i_rx[ETH_TO_PACKET_HANDLER], eth1_i_tx[ETH_TO_PACKET_HANDLER],
                            led_if1, stats_if[1], pcap_if[1], null);

    on tile[1]: led_handler(t1_p_led, led_if1);
  }
  return 0;
}
