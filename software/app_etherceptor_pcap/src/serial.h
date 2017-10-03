#ifndef SERIAL_H
#define SERIAL_H

#include <uart.h>
#include "stats.h"
#include "pcap.h"

#define UART_TX_BUF_SIZE 1024
#define UART_RX_LINE_BUF_SIZE 32

[[combinable]]
void serial_handler(client uart_tx_buffered_if uart_tx, client uart_rx_if uart_rx, client interface stats_if stats[2], client interface pcap_if pcap);

#endif // SERIAL_H
