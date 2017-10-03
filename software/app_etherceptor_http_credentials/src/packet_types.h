#ifndef PACKET_TYPES_H
#define PACKET_TYPES_H

#define ETH_HLEN                14
#define IPV4_HLEN               20
#define UDP_HLEN                8
#define TCP_HLEN                20

#define ETH_PAYLOAD             ETH_HLEN
#define IPv4_PAYLOAD            (ETH_HLEN + IPV4_HLEN)
#define TCP_PAYLOAD             (ETH_HLEN + IPV4_HLEN + TCP_HLEN)

#define ETH_ET_OFFSET           12
#define IPV4_PROT_OFFSET        9

int is_valid_arp_packet(const unsigned char rxbuf[nbytes], unsigned nbytes);
int is_valid_ipv4_packet(const unsigned char rxbuf[nbytes], unsigned nbytes);
int is_valid_icmp_packet(const unsigned char rxbuf[nbytes], unsigned nbytes);
int is_valid_tcp_packet(const unsigned char rxbuf[nbytes], unsigned nbytes);

#endif // PACKET_TYPES_H
