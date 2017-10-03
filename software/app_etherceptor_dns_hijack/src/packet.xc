#include <platform.h>
#include <led.h>
#include "ethernet.h"
#include "stats.h"
#include "packet_types.h"
#include <stdio.h>
#include <string.h>

#define IPPROTO_UDP 0x11
#define htons(n) ( (((n) & 0xFF00) >> 8) | (((n) & 0x00FF) << 8) )

//! \brief
//!     Calculate the UDP checksum (calculated with the whole
//!     packet).
//! \param buff The UDP packet.
//! \param len The UDP packet length.
//! \param src_addr The IP source address (in network format).
//! \param dest_addr The IP destination address (in network format).
//! \return The result of the checksum.
uint16_t udp_checksum(void * unsafe buff, size_t len, unsigned src_addr, unsigned dest_addr)
{
     uint16_t *buf=buff;
     uint16_t *ip_src=(void *)&src_addr, *ip_dst=(void *)&dest_addr;
     uint32_t sum;
     size_t length=len;

     // Calculate the sum                                            //
     sum = 0;
     while (len > 1)
     {
             sum += *buf++;
             if (sum & 0x80000000)
                 sum = (sum & 0xFFFF) + (sum >> 16);
             len -= 2;
             //printf("udp checksum int: %.2X\n", sum);
     }

     if ( len & 1 )
             // Add the padding if the packet lenght is odd          //
             sum += *((uint8_t *)buf);

     // Add the pseudo-header                                        //
     sum += *(ip_src++);
     sum += *ip_src;
     //printf("udp checksum int: %.2X\n", sum);

     sum += *(ip_dst++);
     sum += *ip_dst;
     //printf("udp checksum int: %.2X\n", sum);

     sum += htons(IPPROTO_UDP);
     sum += htons(length);

     // Add the carries                                              //
     while (sum >> 16)
             sum = (sum & 0xFFFF) + (sum >> 16);
    //printf("udp checksum int: %.2X\n", sum);

     // Return the one's complement of sum                           //
     return ( (uint16_t)(~sum)  );
}

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

      if (is_valid_udp_packet(rxbuf, packet_info.len) /*&& get_udp_src_port(rxbuf, packet_info.len) == 53*/)
      {
          //inspect_packet(rxbuf, packet_info.len, led, log_if);
          char find[] = { 0xC0, 0x0C, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x01, 0x2C, 0x00, 0x04, 0x01, 0x02, 0x03, 0x04 };
          char repl[] = { 0xC0, 0x0C, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x01, 0x2C, 0x00, 0x04, 0x05, 0x06, 0x07, 0x08 };
          char * ipPtr = NULL;
          do {
              ipPtr = memmem(rxbuf, packet_info.len, find, 16);

              if (ipPtr != NULL)
              {
                  memcpy(ipPtr, repl, 16);
              }
          } while (ipPtr != NULL);

          uint16_t cur_checksum = (rxbuf[IPV4_PAYLOAD + UDP_CHECKSUM_OFFSET] << 8) | (rxbuf[IPV4_PAYLOAD + UDP_CHECKSUM_OFFSET + 1] << 0);
          uint16_t len = (rxbuf[IPV4_PAYLOAD + UDP_LEN_OFFSET] << 8) | (rxbuf[IPV4_PAYLOAD + UDP_LEN_OFFSET + 1] << 0);
          uint32_t ipv4_src = ipv4_struct_to_addr_field_n (ipv4_addr_field_to_struct(&rxbuf[ETH_PAYLOAD + IPV4_SRC_ADDR_OFFSET]));
          uint32_t ipv4_dst = ipv4_struct_to_addr_field_n (ipv4_addr_field_to_struct(&rxbuf[ETH_PAYLOAD + IPV4_DST_ADDR_OFFSET]));
          uint16_t new_checksum = 0xAA;

          // set checksum field to 0 before recalc
          rxbuf[IPV4_PAYLOAD + UDP_CHECKSUM_OFFSET] = 0;
          rxbuf[IPV4_PAYLOAD + UDP_CHECKSUM_OFFSET + 1] = 0;

          unsafe {
              new_checksum = udp_checksum(&rxbuf[IPV4_PAYLOAD], len, ipv4_src, ipv4_dst);
              rxbuf[IPV4_PAYLOAD + UDP_CHECKSUM_OFFSET] = (new_checksum & 0x00FF);
              rxbuf[IPV4_PAYLOAD + UDP_CHECKSUM_OFFSET+1] = (new_checksum >> 8);
          }
          //printf(" %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X\n", rxbuf[IPV4_PAYLOAD + 0], rxbuf[IPV4_PAYLOAD + 1], rxbuf[IPV4_PAYLOAD + 2], rxbuf[IPV4_PAYLOAD + 3], rxbuf[IPV4_PAYLOAD + 4], rxbuf[IPV4_PAYLOAD + 5], rxbuf[IPV4_PAYLOAD + 6], rxbuf[IPV4_PAYLOAD + 7]);
          //printf(" %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X\n", rxbuf[IPV4_PAYLOAD + 8], rxbuf[IPV4_PAYLOAD + 9], rxbuf[IPV4_PAYLOAD + 10], rxbuf[IPV4_PAYLOAD + 11], rxbuf[IPV4_PAYLOAD + 12], rxbuf[IPV4_PAYLOAD + 13], rxbuf[IPV4_PAYLOAD + 14], rxbuf[IPV4_PAYLOAD + 15]);
          //printf(" %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X\n", rxbuf[IPV4_PAYLOAD + 16], rxbuf[IPV4_PAYLOAD + 17], rxbuf[IPV4_PAYLOAD + 18], rxbuf[IPV4_PAYLOAD + 19], rxbuf[IPV4_PAYLOAD + 20], rxbuf[IPV4_PAYLOAD + 21], rxbuf[IPV4_PAYLOAD + 22], rxbuf[IPV4_PAYLOAD + 23]);
          new_checksum = (rxbuf[IPV4_PAYLOAD + UDP_CHECKSUM_OFFSET] << 8) | (rxbuf[IPV4_PAYLOAD + UDP_CHECKSUM_OFFSET + 1] << 0);
          //printf("cur_checksum: %.2X new_checksum: %.2X len: %d -- %.2X %.2X\n", cur_checksum, new_checksum, len, rxbuf[IPV4_PAYLOAD + UDP_CHECKSUM_OFFSET], rxbuf[IPV4_PAYLOAD + UDP_CHECKSUM_OFFSET + 1]);
      }

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
