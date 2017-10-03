#include <platform.h>
#include <string.h>
#include <stdio.h>
#include "serial.h"

void serial_write_str(client uart_tx_buffered_if uart_tx, uint8_t str[]);
void serial_write_buf(client uart_tx_buffered_if uart_tx, uint8_t buf[], size_t buf_size);
void serial_write_byte(client uart_tx_buffered_if uart_tx, uint8_t byte);
void handle_command(uint8_t cmd[], client uart_tx_buffered_if uart_tx, client interface stats_if stats[2], client interface config_if config);

void serial_handler(client uart_tx_buffered_if uart_tx, client uart_rx_if uart_rx, client interface stats_if stats[2], client interface config_if config)
{
  uint8_t welcome[]   = "\r\nEtherCeptor - Network Diode Application\r\nType /? to see available commands\r\n";
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
          handle_command(rx_buf, uart_tx, stats, config);
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

void handle_command(uint8_t cmd[], client uart_tx_buffered_if uart_tx, client interface stats_if stats[2], client interface config_if config)
{
    if (strcmp(cmd, "/?\r\n") == 0)
    {
        serial_write_str(uart_tx, "Commands:\r\n");
        serial_write_str(uart_tx, "  /?                 - show available commands\r\n");
        serial_write_str(uart_tx, "  /get stat eth1     - eth1 rx/tx packet counters\r\n");
        serial_write_str(uart_tx, "  /get stat eth2     - eth2 rx/tx packet counters\r\n");
        serial_write_str(uart_tx, "  /reset stats       - reset packet counters\r\n");
        serial_write_str(uart_tx, "  /get config        - get configuration\r\n");
        serial_write_str(uart_tx, "  /set config allow_icmp <enabled/disabled>\r\n");
        serial_write_str(uart_tx, "  /set config forward_eth1 <enabled/disabled>\r\n");
        serial_write_str(uart_tx, "  /set config forward_eth2 <enabled/disabled>\r\n");
        serial_write_str(uart_tx, "  /set config allow_arp <enabled/disabled>\r\n");
        serial_write_str(uart_tx, "  /set config allow_icmp <enabled/disabled>\r\n");
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
    else if (strcmp(cmd, "/get config\r\n") == 0)
    {
        unsigned cfg_forward_eth1 = config.get_field(STRUCT_FIELD_FORWARD_ETH1);
        unsigned cfg_forward_eth2 = config.get_field(STRUCT_FIELD_FORWARD_ETH2);
        unsigned cfg_allow_arp    = config.get_field(STRUCT_FIELD_ALLOW_ARP);
        unsigned cfg_allow_icmp   = config.get_field(STRUCT_FIELD_ALLOW_ICMP);
        unsigned cfg_crc32        = config.get_field(STRUCT_FIELD_CRC32);

        uint8_t pbuf[64];

        snprintf(pbuf, 64, "forward eth1: %s eth2: %s\r\n", cfg_forward_eth1 ? "yes" : "no", cfg_forward_eth2 ? "yes" : "no");
        serial_write_str(uart_tx, pbuf);
        snprintf(pbuf, 64, "allow ARP: %s ICMP: %s\r\n", cfg_allow_arp ? "yes" : "no", cfg_allow_icmp ? "yes" : "no");
        serial_write_str(uart_tx, pbuf);
        snprintf(pbuf, 64, "CRC32: %.8X\r\n", cfg_crc32);
        serial_write_str(uart_tx, pbuf);
    }
    else if (strcmp(cmd, "/set config forward_eth2 enabled\r\n") == 0)
    {
        config.set_field(STRUCT_FIELD_FORWARD_ETH2, 1);
        serial_write_str(uart_tx, "config updated!\r\n");
    }
    else if (strcmp(cmd, "/set config forward_eth2 disabled\r\n") == 0)
    {
        config.set_field(STRUCT_FIELD_FORWARD_ETH2, 0);
        serial_write_str(uart_tx, "config updated!\r\n");
    }
    else if (strcmp(cmd, "/set config forward_eth1 enabled\r\n") == 0)
    {
        config.set_field(STRUCT_FIELD_FORWARD_ETH1, 1);
        serial_write_str(uart_tx, "config updated!\r\n");
    }
    else if (strcmp(cmd, "/set config forward_eth1 disabled\r\n") == 0)
    {
        config.set_field(STRUCT_FIELD_FORWARD_ETH1, 0);
        serial_write_str(uart_tx, "config updated!\r\n");
    }
    else if (strcmp(cmd, "/set config allow_arp enabled\r\n") == 0)
    {
        config.set_field(STRUCT_FIELD_ALLOW_ARP, 1);
        serial_write_str(uart_tx, "config updated!\r\n");
    }
    else if (strcmp(cmd, "/set config allow_arp disabled\r\n") == 0)
    {
        config.set_field(STRUCT_FIELD_ALLOW_ICMP, 0);
        serial_write_str(uart_tx, "config updated!\r\n");
    }
    else if (strcmp(cmd, "/set config allow_icmp enabled\r\n") == 0)
    {
        config.set_field(STRUCT_FIELD_ALLOW_ICMP, 1);
        serial_write_str(uart_tx, "config updated!\r\n");
    }
    else if (strcmp(cmd, "/set config allow_icmp disabled\r\n") == 0)
    {
        config.set_field(STRUCT_FIELD_ALLOW_ICMP, 0);
        serial_write_str(uart_tx, "config updated!\r\n");
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
