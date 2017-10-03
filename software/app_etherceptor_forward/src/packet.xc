#include <platform.h>
#include <led.h>
#include "ethernet.h"
#include "stats.h"

[[combinable]]
void packet_handler(client ethernet_cfg_if cfg,
                 client ethernet_rx_if rx,
                 client ethernet_tx_if tx,
                 client interface led_if led,
                 server interface stats_if stats
                 )
{
  unsigned stat_rx_total=0, stat_tx_total=0;
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

      tx.send_packet(rxbuf, packet_info.len, ETHERNET_ALL_INTERFACES);
      stat_tx_total++;

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
    }
  }
}
