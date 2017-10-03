#ifndef PACKET_H
#define PACKET_H

#include <platform.h>
#include <led.h>
#include "ethernet.h"
#include "stats.h"
#include "config.h"

[[combinable]]
void packet_handler(client ethernet_cfg_if cfg,
                 client ethernet_rx_if rx,
                 client ethernet_tx_if tx,
                 client interface led_if led,
                 server interface stats_if stats,
                 client interface config_if config
             );

#endif // PACKET_H
