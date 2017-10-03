#ifndef CONFIG_H
#define CONFIG_H

#include <platform.h>
#include <stdint.h>
#include "packet_types.h"

#define IF_ETH1                     0
#define IF_ETH2                     1

#define FW_NR_RULES                 10

#define FW_TYPE_ALL                 0
#define FW_TYPE_ETH_ADDR            1
#define FW_TYPE_ETH_PROT            2
#define FW_TYPE_IPV4_ADDR           3
#define FW_TYPE_IPV4_PROT           4
#define FW_TYPE_UDP_PORT            5
#define FW_TYPE_TCP_PORT            6

#define FW_DIR_IN                   0
#define FW_DIR_OUT                  1
#define FW_DIR_INOUT                2

#define FW_ACTION_DROP              0
#define FW_ACTION_FORWARD           1
#define FW_ACTION_NONE              2

#define FW_RULE_INVALID             0

#define REQ_UPDATE_CONFIG           0
#define REQ_SEND_CONFIG             1


struct rule {
    unsigned type;
    uint16_t prot;
    struct mac mac;
    struct ipv4 ip;
    struct ipv4 mask;
    uint16_t nport[2];
    unsigned direction;
    unsigned action;
    unsigned count;
    unsigned valid;
};

struct config {
    struct rule rules[FW_NR_RULES];
    unsigned crc32;
};

interface config_if {

    [[notification]]
    slave void update();

    [[clears_notification]]
    struct config get();

    void set(struct config);

    void update_cached_from_packet_handlers();

    struct config retrieve(int iface);

    unsigned get_req_type();

    unsigned cache_valid();

    [[clears_notification]]
    void send_config(struct config c);
};

[[combinable]]
void config_handler(server interface config_if cfg_i[3]);

#endif // CONFIG_H
