#ifndef SERIAL_H
#define SERIAL_H

#include <uart.h>
#include "stats.h"
#include "datalog.h"


#define UART_TX_BUF_SIZE 1024
#define UART_RX_LINE_BUF_SIZE 64

void serial_write_str(client uart_tx_buffered_if uart_tx, uint8_t str[]);
void serial_write_buf(client uart_tx_buffered_if uart_tx, uint8_t buf[], size_t buf_size);
void serial_write_byte(client uart_tx_buffered_if uart_tx, uint8_t byte);
void serial_handler(client uart_tx_buffered_if uart_tx, client uart_rx_if uart_rx, client interface stats_if stats[2], server interface info_log_if log_if[2]);

#endif // SERIAL_H
