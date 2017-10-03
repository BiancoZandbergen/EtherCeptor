#include <platform.h>
#include <led.h>
#include <stdio.h>
#include "ethernet.h"
#include "stats.h"
#include "pcap.h"

#define FALSE 0
#define TRUE !FALSE

#define DELAY_100MS 10000000

[[combinable]]
void packet_handler(client ethernet_cfg_if cfg,
                 client ethernet_rx_if rx,
                 client ethernet_tx_if tx,
                 client interface led_if led,
                 server interface stats_if stats,
                 client interface pcap_if pcap,
                 in port ?button
                 )
{
  unsigned stat_rx_total=0, stat_tx_total=0;
  unsigned enable_capture = FALSE;
  timer btimer;
  unsigned btime, bcounter=0;

  btimer :> btime;

  led.blink(3);

  while (1)
  {
    select {
        // todo move button handling to somewhere more appropriate
        case btimer when timerafter(btime + DELAY_100MS) :> void:
            if (!isnull(button))
            {
                unsigned button_state;
                button :> button_state;
                if (button_state == 0)
                {
                    bcounter++;

                    if (bcounter == 2)
                    {
                        if (enable_capture)
                        {
                            pcap.stop();
                        }
                        else
                        {
                            pcap.start();
                        }
                    }
                }
                else
                {
                    bcounter = 0;
                }
            }
            btime += DELAY_100MS;
            break;
        case rx.packet_ready():
            unsigned char rxbuf[ETHERNET_MAX_PACKET_SIZE];
            //unsigned char txbuf[ETHERNET_MAX_PACKET_SIZE];
            ethernet_packet_info_t packet_info;
            rx.get_packet(packet_info, rxbuf, ETHERNET_MAX_PACKET_SIZE);
            stat_rx_total++;

            tx.send_packet(rxbuf, packet_info.len, ETHERNET_ALL_INTERFACES);
            stat_tx_total++;

            if (enable_capture)
            {
              //printf("enable_capture\n");
                if (!pcap.full())
                {
                  //printf("!pcap.full\n");
                    pcap.capture(rxbuf, packet_info.len);
                }
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
        case pcap.update():
            unsigned not_type = pcap.get_not_type();
            if (not_type == PCAP_NOT_START_CAPTURE)
            {
                enable_capture = TRUE;
                led.led_on();
                led.blink_enable_after(500);
            }
            else if (not_type == PCAP_NOT_STOP_CAPTURE)
            {
                enable_capture = FALSE;
                led.led_on();
                led.blink_enable_after(500);
            }
            break;
        }
  }
}
