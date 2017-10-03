#ifndef CONFIG_H
#define CONFIG_H

#include <platform.h>

#define STRUCT_FIELD_FORWARD_ETH1 0
#define STRUCT_FIELD_FORWARD_ETH2 1
#define STRUCT_FIELD_ALLOW_ARP    2
#define STRUCT_FIELD_ALLOW_ICMP   3
#define STRUCT_FIELD_CRC32        4

struct config {
    unsigned forward_eth1;
    unsigned forward_eth2;
    unsigned allow_arp;
    unsigned allow_icmp;
    unsigned crc32;
};

interface config_if {
    [[clears_notification]]
    unsigned forward();

    [[clears_notification]]
    unsigned allow_arp();

    [[clears_notification]]
    unsigned allow_icmp();

    [[notification]]
    slave void update();

    unsigned get_field(unsigned field);

    void set_field(unsigned field, unsigned value);
};

[[combinable]]
void config_handler(server interface config_if cfg_i[3]);

#endif // CONFIG_H
