#include <platform.h>
#include <stdio.h>
#include <led.h>
#include <string.h>
#include "ethernet.h"
#include "stats.h"
#include "config.h"
#include "packet_types.h"

#define FALSE 0
#define TRUE !FALSE

int verdict (const unsigned char rxbuf[nbytes], unsigned nbytes, struct config &cfg, unsigned iface);

[[combinable]]
void packet_handler(client ethernet_cfg_if cfg,
                 client ethernet_rx_if rx,
                 client ethernet_tx_if tx,
                 client interface led_if led,
                 server interface stats_if stats,
                 client interface config_if config,
                 unsigned iface
                 )
{
  unsigned stat_rx_total=0, stat_tx_total=0;
  struct config rules;

  rules = config.get();

  for (int i = 0; i < FW_NR_RULES; i++)
  {
      rules.rules[i].count = 0;
  }


  led.blink(3);

  while (1)
  {
    select {
    case rx.packet_ready():
      unsigned char rxbuf[ETHERNET_MAX_PACKET_SIZE];
      //unsigned char txbuf[ETHERNET_MAX_PACKET_SIZE];
      ethernet_packet_info_t packet_info;

      rx.get_packet(packet_info, rxbuf, ETHERNET_MAX_PACKET_SIZE);
      stat_rx_total++;

      if (verdict (rxbuf, packet_info.len, rules, iface) == FW_ACTION_FORWARD)
      {
          tx.send_packet(rxbuf, packet_info.len, ETHERNET_ALL_INTERFACES);
          stat_tx_total++;
      }

      led.blink(1);
      break;
    case stats.reset():
      stat_rx_total = 0;
      stat_tx_total = 0;
      break;
    case stats.rx_total() -> unsigned stat:
      stat = stat_rx_total;
      break;
    case stats.tx_total() -> unsigned stat:
      stat = stat_tx_total;
      break;
    case config.update():
      unsigned req_type = config.get_req_type();

      if (req_type == REQ_UPDATE_CONFIG)
      {
          rules = config.get();
          for (int i = 0; i < FW_NR_RULES; i++)
          {
              rules.rules[i].count = 0;
          }
      }
      else if (req_type == REQ_SEND_CONFIG)
      {
          config.send_config(rules);
      }
      break;
    }
  }
}

int verdict (const unsigned char rxbuf[nbytes], unsigned nbytes, struct config &cfg, unsigned iface)
{
    for (int i = 0; i < FW_NR_RULES; i++)
    {
        if (cfg.rules[i].valid != FW_RULE_INVALID)
        {
            unsigned match = FALSE;

            if (cfg.rules[i].type == FW_TYPE_ALL)
            {

                if ( (cfg.rules[i].direction == FW_DIR_OUT && iface == IF_ETH1) ||
                     (cfg.rules[i].direction == FW_DIR_IN && iface == IF_ETH2) ||
                     (cfg.rules[i].direction == FW_DIR_INOUT))
                {
                    match = TRUE;
                }
            }
            else if (cfg.rules[i].type == FW_TYPE_ETH_ADDR)
            {
                if ( (cfg.rules[i].direction == FW_DIR_OUT && iface == IF_ETH1) )
                {
                    struct mac m = mac_addr_field_to_struct(&rxbuf[ETH_DST_ADDR_OFFSET]);
                    if (memcmp(&m, &cfg.rules[i].mac, sizeof (struct mac)) == 0) match = TRUE;
                }
                else if ( (cfg.rules[i].direction == FW_DIR_IN && iface == IF_ETH2) )
                {
                    struct mac m = mac_addr_field_to_struct(&rxbuf[ETH_SRC_ADDR_OFFSET]);
                    if (memcmp(&m, &cfg.rules[i].mac, sizeof (struct mac)) == 0) match = TRUE;
                }
                else if ( (cfg.rules[i].direction == FW_DIR_INOUT) )
                {
                    struct mac m1 = mac_addr_field_to_struct(&rxbuf[ETH_SRC_ADDR_OFFSET]);
                    struct mac m2 = mac_addr_field_to_struct(&rxbuf[ETH_DST_ADDR_OFFSET]);
                    if (memcmp(&m1, &cfg.rules[i].mac, sizeof (struct mac)) == 0 ||
                        memcmp(&m2, &cfg.rules[i].mac, sizeof (struct mac)) == 0) match = TRUE;
                }
            }
            else if (cfg.rules[i].type == FW_TYPE_ETH_PROT)
            {
                uint16_t prot = *((const uint16_t*)&rxbuf[ETH_ET_OFFSET]);
                if ( (cfg.rules[i].direction == FW_DIR_OUT && iface == IF_ETH1) ||
                     (cfg.rules[i].direction == FW_DIR_IN && iface == IF_ETH2) ||
                     (cfg.rules[i].direction == FW_DIR_INOUT))
                {
                    if (prot == cfg.rules[i].prot) match = TRUE;
                }
            }
            else if (cfg.rules[i].type == FW_TYPE_IPV4_ADDR)
            {
                if (is_valid_ipv4_packet(rxbuf, nbytes))
                {
                    if ( (cfg.rules[i].direction == FW_DIR_OUT && iface == IF_ETH1) )
                    {
                        struct ipv4 m = ipv4_addr_field_to_struct(&rxbuf[ETH_PAYLOAD + IPV4_DST_ADDR_OFFSET]);
                        if (ipv4_check_mask(m, cfg.rules[i].ip, cfg.rules[i].mask)) match = TRUE;
                    }
                    else if ( (cfg.rules[i].direction == FW_DIR_IN && iface == IF_ETH2) )
                    {
                        struct ipv4 m = ipv4_addr_field_to_struct(&rxbuf[ETH_PAYLOAD + IPV4_SRC_ADDR_OFFSET]);
                        if (ipv4_check_mask(m, cfg.rules[i].ip, cfg.rules[i].mask)) match = TRUE;
                    }
                    else if ( (cfg.rules[i].direction == FW_DIR_INOUT) )
                    {
                        struct ipv4 m1 = ipv4_addr_field_to_struct(&rxbuf[ETH_PAYLOAD + IPV4_DST_ADDR_OFFSET]);
                        struct ipv4 m2 = ipv4_addr_field_to_struct(&rxbuf[ETH_PAYLOAD + IPV4_SRC_ADDR_OFFSET]);
                        if (ipv4_check_mask(m1, cfg.rules[i].ip, cfg.rules[i].mask) ||
                            ipv4_check_mask(m2, cfg.rules[i].ip, cfg.rules[i].mask)) match = TRUE;
                    }
                }
            }
            else if (cfg.rules[i].type == FW_TYPE_IPV4_PROT)
            {
                if (is_valid_ipv4_packet(rxbuf, nbytes))
                {
                    uint8_t prot = *((const uint8_t*)&rxbuf[ETH_PAYLOAD + IPV4_PROT_OFFSET]);
                    if ( (cfg.rules[i].direction == FW_DIR_OUT && iface == IF_ETH1) ||
                         (cfg.rules[i].direction == FW_DIR_IN && iface == IF_ETH2) ||
                         (cfg.rules[i].direction == FW_DIR_INOUT))
                    {
                        if (prot == cfg.rules[i].prot) match = TRUE;
                    }
                }
            }
            else if (cfg.rules[i].type == FW_TYPE_UDP_PORT)
            {
                if (is_valid_udp_packet(rxbuf, nbytes))
                {
                    uint16_t dst_port = get_udp_dst_port(rxbuf, nbytes);

                    if ( (cfg.rules[i].direction == FW_DIR_OUT && iface == IF_ETH1) ||
                         (cfg.rules[i].direction == FW_DIR_IN && iface == IF_ETH2) ||
                         (cfg.rules[i].direction == FW_DIR_INOUT) )
                    {
                        if (dst_port >= cfg.rules[i].nport[0] &&
                            dst_port <= cfg.rules[i].nport[1])
                            match = TRUE;
                    }
                }
            }
            else if (cfg.rules[i].type == FW_TYPE_TCP_PORT)
            {
                if (is_valid_tcp_packet(rxbuf, nbytes))
                {
                    uint16_t dst_port = get_tcp_dst_port(rxbuf, nbytes);

                    if ( (cfg.rules[i].direction == FW_DIR_OUT && iface == IF_ETH1) ||
                         (cfg.rules[i].direction == FW_DIR_IN && iface == IF_ETH2) ||
                         (cfg.rules[i].direction == FW_DIR_INOUT) )
                    {
                        if (dst_port >= cfg.rules[i].nport[0] &&
                            dst_port <= cfg.rules[i].nport[1])
                            match = TRUE;
                    }
                }
            }

            if (match)
            {
                cfg.rules[i].count++;
                if (cfg.rules[i].action == FW_ACTION_DROP || cfg.rules[i].action == FW_ACTION_FORWARD)
                {
                    return cfg.rules[i].action;
                }
            }
        }
    }

    return FW_ACTION_FORWARD;
}
