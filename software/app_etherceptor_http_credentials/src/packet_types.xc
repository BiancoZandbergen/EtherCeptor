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
