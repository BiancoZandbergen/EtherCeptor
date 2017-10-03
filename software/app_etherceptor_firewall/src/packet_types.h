#ifndef PACKET_TYPES_H
#define PACKET_TYPES_H

#include <stdint.h>

struct mac {
    uint8_t addr[6];
};

struct ipv4 {
    uint8_t addr[4];
};

#define ETH_HLEN                14
#define IPV4_HLEN               20
#define UDP_HLEN                8
#define TCP_HLEN                20

#define ETH_PAYLOAD             ETH_HLEN
#define IPV4_PAYLOAD            (ETH_HLEN + IPV4_HLEN)
#define TCP_PAYLOAD             (ETH_HLEN + IPV4_HLEN + TCP_HLEN)

#define ETH_DST_ADDR_OFFSET     0
#define ETH_SRC_ADDR_OFFSET     6
#define ETH_ET_OFFSET           12
#define IPV4_PROT_OFFSET        9
#define IPV4_DST_ADDR_OFFSET    16
#define IPV4_SRC_ADDR_OFFSET    12
#define TCP_DST_PORT_OFFSET     2
#define TCP_SRC_PORT_OFFSET     0
#define UDP_DST_PORT_OFFSET     2
#define UDP_SRC_PORT_OFFSET     0


int is_valid_arp_packet(const unsigned char rxbuf[nbytes], unsigned nbytes);
int is_valid_ipv4_packet(const unsigned char rxbuf[nbytes], unsigned nbytes);
int is_valid_icmp_packet(const unsigned char rxbuf[nbytes], unsigned nbytes);
int is_valid_tcp_packet(const unsigned char rxbuf[nbytes], unsigned nbytes);
int is_valid_udp_packet(const unsigned char rxbuf[nbytes], unsigned nbytes);
uint16_t get_tcp_dst_port(const unsigned char rxbuf[nbytes], unsigned nbytes);
uint16_t get_tcp_src_port(const unsigned char rxbuf[nbytes], unsigned nbytes);
uint16_t get_udp_dst_port(const unsigned char rxbuf[nbytes], unsigned nbytes);
uint16_t get_udp_src_port(const unsigned char rxbuf[nbytes], unsigned nbytes);
struct mac mac_addr_field_to_struct(const unsigned char addrstart[]);
struct ipv4 ipv4_addr_field_to_struct(const unsigned char addrstart[]);
unsigned ipv4_struct_to_addr_field(struct ipv4 ip);
unsigned ipv4_check_mask(struct ipv4 ip1, struct ipv4 ip2, struct ipv4 mask);


#endif // PACKET_TYPES_H
