#include <platform.h>
#include "packet_types.h"

int is_valid_arp_packet(const unsigned char rxbuf[nbytes], unsigned nbytes)
{
    // Ethernet ethertype
    if (rxbuf[ETH_ET_OFFSET] != 0x08 || rxbuf[ETH_ET_OFFSET+1] != 0x06)
    {
        return 0;
    }

    // ARP Hardware Type
    if (rxbuf[ETH_PAYLOAD] != 0x00 || rxbuf[ETH_PAYLOAD+1] != 0x01)
    {
        return 0;
    }

    return 1;
}

int is_valid_ipv4_packet(const unsigned char rxbuf[nbytes], unsigned nbytes)
{
    if (rxbuf[ETH_ET_OFFSET] != 0x08 || rxbuf[ETH_ET_OFFSET+1] != 0x00)
    {
        return 0;
    }

    return 1;
}

int is_valid_tcp_packet(const unsigned char rxbuf[nbytes], unsigned nbytes)
{
    if (! is_valid_ipv4_packet(rxbuf, nbytes))
    {
        return 0;
    }

    if (rxbuf[ETH_PAYLOAD + IPV4_PROT_OFFSET] != 0x06)
    {
        return 0;
    }

    return 1;
}

int is_valid_udp_packet(const unsigned char rxbuf[nbytes], unsigned nbytes)
{
    if (! is_valid_ipv4_packet(rxbuf, nbytes))
    {
        return 0;
    }

    if (rxbuf[ETH_PAYLOAD + IPV4_PROT_OFFSET] != 0x11)
    {
        return 0;
    }

    return 1;
}

int is_valid_icmp_packet(const unsigned char rxbuf[nbytes], unsigned nbytes)
{
    if (! is_valid_ipv4_packet(rxbuf, nbytes))
    {
        return 0;
    }

    if (rxbuf[ETH_PAYLOAD + IPV4_PROT_OFFSET] != 0x01)
    {
        return 0;
    }

    return 1;
}

struct mac mac_addr_field_to_struct(const unsigned char addrstart[])
{
    struct mac m;
    m.addr[0] = addrstart[5];
    m.addr[1] = addrstart[4];
    m.addr[2] = addrstart[3];
    m.addr[3] = addrstart[2];
    m.addr[4] = addrstart[1];
    m.addr[5] = addrstart[0];

    return m;
}

struct ipv4 ipv4_addr_field_to_struct(const unsigned char addrstart[])
{
    struct ipv4 m;
    m.addr[0] = addrstart[3];
    m.addr[1] = addrstart[2];
    m.addr[2] = addrstart[1];
    m.addr[3] = addrstart[0];

    return m;
}

unsigned ipv4_struct_to_addr_field(struct ipv4 ip)
{
    return (ip.addr[3]<<24)|(ip.addr[2]<<16)|(ip.addr[1]<<8)|(ip.addr[0]<<0);
}

unsigned ipv4_struct_to_addr_field_n(struct ipv4 ip)
{
    return (ip.addr[0]<<24)|(ip.addr[1]<<16)|(ip.addr[2]<<8)|(ip.addr[3]<<0);
}

unsigned ipv4_check_mask(struct ipv4 ip1, struct ipv4 ip2, struct ipv4 mask)
{
    unsigned ip1_u, ip2_u, mask_u;
    ip1_u = ipv4_struct_to_addr_field(ip1);
    ip2_u = ipv4_struct_to_addr_field(ip2);
    mask_u = ipv4_struct_to_addr_field(mask);

    return ((ip1_u & mask_u) == (ip2_u & mask_u));
}

uint16_t get_tcp_dst_port(const unsigned char rxbuf[nbytes], unsigned nbytes)
{
    return (rxbuf[IPV4_PAYLOAD + TCP_DST_PORT_OFFSET] << 8) | (rxbuf[IPV4_PAYLOAD + TCP_DST_PORT_OFFSET + 1] << 0);
}

uint16_t get_tcp_src_port(const unsigned char rxbuf[nbytes], unsigned nbytes)
{
    return (rxbuf[IPV4_PAYLOAD + TCP_SRC_PORT_OFFSET] << 8) | (rxbuf[IPV4_PAYLOAD + TCP_SRC_PORT_OFFSET + 1] << 0);
}

uint16_t get_udp_dst_port(const unsigned char rxbuf[nbytes], unsigned nbytes)
{
    return (rxbuf[IPV4_PAYLOAD + UDP_DST_PORT_OFFSET] << 8) | (rxbuf[IPV4_PAYLOAD + UDP_DST_PORT_OFFSET + 1] << 0);
}

uint16_t get_udp_src_port(const unsigned char rxbuf[nbytes], unsigned nbytes)
{
    return (rxbuf[IPV4_PAYLOAD + UDP_SRC_PORT_OFFSET] << 8) | (rxbuf[IPV4_PAYLOAD + UDP_SRC_PORT_OFFSET + 1] << 0);
}
