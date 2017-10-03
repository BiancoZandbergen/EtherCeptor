#include <platform.h>
#include <string.h>
#include <stdio.h>
#include "serial.h"

void serial_write_str(client uart_tx_buffered_if uart_tx, uint8_t str[]);
void serial_write_buf(client uart_tx_buffered_if uart_tx, uint8_t buf[], size_t buf_size);
void serial_write_byte(client uart_tx_buffered_if uart_tx, uint8_t byte);
void handle_command(uint8_t cmd[], client uart_tx_buffered_if uart_tx, client interface stats_if stats[2]);

void serial_handler(client uart_tx_buffered_if uart_tx, client uart_rx_if uart_rx, client interface stats_if stats[2])
{
  uint8_t welcome[]   = "\r\nEtherCeptor - DNS Hijack Application\r\nType /? to see available commands\r\n";
  uint8_t error_ovf[] = "\r\nUART Receive Command Overflow\r\n";
  uint8_t rx_buf[UART_RX_LINE_BUF_SIZE];
  unsigned rx_ptr = 0;

  serial_write_str(uart_tx, welcome);

  while (1)
  {
      rx_buf[rx_ptr] = uart_rx.wait_for_data_and_read();
      serial_write_byte(uart_tx, rx_buf[rx_ptr]);

      if (rx_ptr >= 1 && rx_buf[rx_ptr-1] == '\r' && rx_buf[rx_ptr] == '\n')
      {
          rx_buf[rx_ptr + 1] = '\0';
          handle_command(rx_buf, uart_tx, stats);
          rx_ptr = 0;
      }
      else if (rx_ptr >= UART_RX_LINE_BUF_SIZE - 2)
      {
          serial_write_str(uart_tx, error_ovf);
          rx_ptr = 0;
      }
      else
      {
          rx_ptr++;
      }
  }

}

void handle_command(uint8_t cmd[], client uart_tx_buffered_if uart_tx, client interface stats_if stats[2])
{
    if (strcmp(cmd, "/?\r\n") == 0)
    {
        serial_write_str(uart_tx, "Commands:\r\n");
        serial_write_str(uart_tx, "  /?                 - show available commands\r\n");
        serial_write_str(uart_tx, "  /get stat eth1     - eth1 rx/tx packet counters\r\n");
        serial_write_str(uart_tx, "  /get stat eth2     - eth2 rx/tx packet counters\r\n");
        serial_write_str(uart_tx, "  /reset stats       - reset packet counters\r\n");
    }
    else if (strcmp(cmd, "/get stat eth1\r\n") == 0)
    {
        unsigned rx_total = stats[0].rx_total();
        unsigned tx_total = stats[1].tx_total();
        uint8_t pbuf[64];
        snprintf(pbuf, 64, "eth1 rx_total: %u tx_total: %u\r\n", rx_total, tx_total);
        serial_write_str(uart_tx, pbuf);
    }
    else if (strcmp(cmd, "/get stat eth2\r\n") == 0)
    {
        unsigned rx_total = stats[1].rx_total();
        unsigned tx_total = stats[0].tx_total();
        uint8_t pbuf[64];
        snprintf(pbuf, 64, "eth2 rx_total: %u tx_total: %u\r\n", rx_total, tx_total);
        serial_write_str(uart_tx, pbuf);
    }
    else if (strcmp(cmd, "/reset stats\r\n") == 0)
    {
        stats[0].reset();
        stats[1].reset();
        serial_write_str(uart_tx, "statistics reset\r\n");
    }
    else
    {
        serial_write_str(uart_tx, "Invalid command, type '/?' to see available commands\r\n");
    }
}

void serial_write_byte(client uart_tx_buffered_if uart_tx, uint8_t byte)
{
    while (uart_tx.get_available_buffer_size() < 1)
        ;
    uart_tx.write(byte);
}

void serial_write_str(client uart_tx_buffered_if uart_tx, uint8_t str[])
{
    size_t len = strlen(str);

    while (uart_tx.get_available_buffer_size() < len)
        ;

    for (size_t i = 0; i < len; i++)
    {
        uart_tx.write(str[i]);
    }
}

void serial_write_buf(client uart_tx_buffered_if uart_tx, uint8_t buf[], size_t buf_size)
{
    while (uart_tx.get_available_buffer_size() < buf_size)
        ;

    for (size_t i = 0; i < buf_size; i++)
    {
        uart_tx.write(buf[i]);
    }
}
