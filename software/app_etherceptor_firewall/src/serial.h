#ifndef SERIAL_H
#define SERIAL_H

#include <uart.h>
#include "stats.h"
#include "config.h"

#define UART_TX_BUF_SIZE 2048
#define UART_RX_LINE_BUF_SIZE 64

void serial_handler(client uart_tx_buffered_if uart_tx, client uart_rx_if uart_rx, client interface stats_if stats[2], client interface config_if config);

#endif // SERIAL_H
