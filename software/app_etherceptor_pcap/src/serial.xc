#include <platform.h>
#include <string.h>
#include <stdio.h>
#include <timer.h>
#include "serial.h"
#include "pcap.h"

void serial_write_str(client uart_tx_buffered_if uart_tx, uint8_t str[]);
void serial_write_buf(client uart_tx_buffered_if uart_tx, uint8_t buf[], size_t buf_size);
void serial_write_byte(client uart_tx_buffered_if uart_tx, uint8_t byte);
void handle_command(uint8_t cmd[], client uart_tx_buffered_if uart_tx, client interface stats_if stats[2], client interface pcap_if pcap);

[[combinable]]
void serial_handler(client uart_tx_buffered_if uart_tx, client uart_rx_if uart_rx, client interface stats_if stats[2], client interface pcap_if pcap)
{
  uint8_t welcome[]   = "\r\nEtherCeptor - PCAP Capture Application\r\nType /? to see available commands\r\nUse button or serial interface to start a capture\r\n";
  uint8_t error_ovf[] = "\r\nUART Receive Command Overflow\r\n";
  uint8_t rx_buf[UART_RX_LINE_BUF_SIZE];
  unsigned rx_ptr = 0;

  serial_write_str(uart_tx, welcome);

  unsigned psize = pcap.get_pcap_size();
  unsigned pcount = pcap.get_pcap_count();

  if (psize < 40 || pcount == 0)
  {
      serial_write_str(uart_tx, "No capture loaded\r\n");
  }
  else
  {
      uint8_t pbuf[64];
      snprintf(pbuf, 64, "Capture loaded: %u packets %u bytes\r\n", pcount, psize);
      serial_write_str(uart_tx, pbuf);
  }

  while (1)
  {
      select {
          case uart_rx.data_ready():
              rx_buf[rx_ptr] = uart_rx.read();
              serial_write_byte(uart_tx, rx_buf[rx_ptr]);

              if (rx_ptr >= 1 && rx_buf[rx_ptr-1] == '\r' && rx_buf[rx_ptr] == '\n')
              {
                  rx_buf[rx_ptr + 1] = '\0';
                  handle_command(rx_buf, uart_tx, stats, pcap);
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
              break;
          case pcap.update():
              unsigned not_type = pcap.get_not_type();
              if (not_type == PCAP_NOT_START_CAPTURE)
              {
                  serial_write_str(uart_tx, "Packet capture started\r\n");
              }
              else if (not_type == PCAP_NOT_STOP_CAPTURE)
              {
                  uint8_t pbuf[64];
                  psize = pcap.get_pcap_size();
                  pcount = pcap.get_pcap_count();
                  snprintf(pbuf, 64, "%u packets captured (%u bytes)\r\n", pcount, psize);
                  serial_write_str(uart_tx, pbuf);
              }
              break;
      }
  }

}

void handle_command(uint8_t cmd[], client uart_tx_buffered_if uart_tx, client interface stats_if stats[2], client interface pcap_if pcap)
{
    if (strcmp(cmd, "/?\r\n") == 0)
    {
        serial_write_str(uart_tx, "Commands:\r\n");
        serial_write_str(uart_tx, "  /?                 - show available commands\r\n");
        serial_write_str(uart_tx, "  /get stat eth1     - eth1 rx/tx packet counters\r\n");
        serial_write_str(uart_tx, "  /get stat eth2     - eth2 rx/tx packet counters\r\n");
        serial_write_str(uart_tx, "  /reset stats       - reset packet counters\r\n");
        serial_write_str(uart_tx, "  /capture info      - current capture buffer state\r\n");
        serial_write_str(uart_tx, "  /capture start     - start capture\r\n");
        serial_write_str(uart_tx, "  /capture stop      - stop capture\r\n");
        serial_write_str(uart_tx, "  /capture erase     - erase current capture buffer and flash\r\n");
        serial_write_str(uart_tx, "  /capture transfer  - tranfer current capture to PC over serial port\r\n");
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
    else if (strcmp(cmd, "/capture info\r\n") == 0)
    {
        //serial_write_str(uart_tx, "capture erased\r\n");
        unsigned psize = pcap.get_pcap_size();
        unsigned pcount = pcap.get_pcap_count();
        if (psize < 40 || pcount == 0)
        {
            serial_write_str(uart_tx, "No capture in buffer\r\n");
        }
        else
        {
            uint8_t pbuf[64];
            snprintf(pbuf, 64, "Capture: %u packets %u bytes\r\n", pcount, psize);
            serial_write_str(uart_tx, pbuf);
        }
    }
    else if (strcmp(cmd, "/capture start\r\n") == 0)
    {
        pcap.start();
        //serial_write_str(uart_tx, "capture started\r\n");
    }
    else if (strcmp(cmd, "/capture stop\r\n") == 0)
    {
        pcap.stop();
        //serial_write_str(uart_tx, "capture stopped\r\n");
    }
    else if (strcmp(cmd, "/capture erase\r\n") == 0)
    {
        pcap.erase();
        serial_write_str(uart_tx, "capture erased\r\n");
    }
    else if (strcmp(cmd, "/capture transfer\r\n") == 0)
    {
        serial_write_str(uart_tx, "Transferring capture over serial link in 10 seconds.\r\nClear buffer and save as binary after reception\r\n");
        delay_seconds(10);
        unsigned cap_size = pcap.get_pcap_size();
        unsigned buf_free = 0;
        for (int i=0; i<cap_size; i++)
        {
            if (buf_free == 0)
            {
                while (1)
                {
                    delay_milliseconds(20);
                    buf_free = uart_tx.get_available_buffer_size();
                    if (buf_free > 0) break;
                }
            }
            uint8_t byte = pcap.get_buf_byte(i);
            uart_tx.write(byte);
            buf_free--;
        }
    }
    else
    {
        serial_write_str(uart_tx, "Invalid command, type '/?' to see available commands\r\n");
    }
}

void serial_write_byte(client uart_tx_buffered_if uart_tx, uint8_t byte)
{
    while (uart_tx.get_available_buffer_size() < 1)
    {
        delay_milliseconds(10);
    }
    uart_tx.write(byte);
}

void serial_write_str(client uart_tx_buffered_if uart_tx, uint8_t str[])
{
    size_t len = strlen(str);

    while (uart_tx.get_available_buffer_size() < len)
    {
        delay_milliseconds(10);
    }

    for (size_t i = 0; i < len; i++)
    {
        uart_tx.write(str[i]);
    }
}

void serial_write_buf(client uart_tx_buffered_if uart_tx, uint8_t buf[], size_t buf_size)
{
    while (uart_tx.get_available_buffer_size() < buf_size)
    {
        delay_milliseconds(10);
    }

    for (size_t i = 0; i < buf_size; i++)
    {
        uart_tx.write(buf[i]);
    }
}
