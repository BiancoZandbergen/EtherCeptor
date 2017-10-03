#include <platform.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "serial.h"

#define FALSE 0
#define TRUE !FALSE

void serial_write_str(client uart_tx_buffered_if uart_tx, uint8_t str[]);
void serial_write_buf(client uart_tx_buffered_if uart_tx, uint8_t buf[], size_t buf_size);
void serial_write_byte(client uart_tx_buffered_if uart_tx, uint8_t byte);
void handle_command(uint8_t cmd[], client uart_tx_buffered_if uart_tx, client interface stats_if stats[2], client interface config_if config);
unsigned parse_rules_set(char cmd[], struct config &cfg);
void print_rules(client uart_tx_buffered_if uart_tx, struct config &cfg1, struct config &cfg2);

void serial_handler(client uart_tx_buffered_if uart_tx, client uart_rx_if uart_rx, client interface stats_if stats[2], client interface config_if config)
{
  uint8_t welcome[]   = "\r\nEtherCeptor - Firewall Application\r\nType /? to see available commands\r\nConnect ETH1 to computer and ETH2 to network\r\n";
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
        serial_write_str(uart_tx, "  /rules print       - print firewall rules\r\n");
        serial_write_str(uart_tx, "  /rules flush       - remove all rules\r\n");
        serial_write_str(uart_tx, "  /rules reset       - reset rule match counters\r\n");
        serial_write_str(uart_tx, "  /rules swap <rule1> <rule2>\r\n");
        serial_write_str(uart_tx, "  /rules set <nr> <type> [<cond>] <dir> <action>\r\n");
        serial_write_str(uart_tx, "  /rules set 1 ALL IN FORWARD\r\n");
        serial_write_str(uart_tx, "  /rules set 2 ETH_ADDR AA:BB:CC:DD:EE:FF OUT DROP\r\n");
        serial_write_str(uart_tx, "  /rules set 3 ETH_PROT 0x0806 INOUT NONE\r\n");
        serial_write_str(uart_tx, "  /rules set 4 IPV4_ADDR 10.0.0.1 MASK 255.255.255.255 IN FORWARD\r\n");
        serial_write_str(uart_tx, "  /rules set 5 IPV4_PROT 0x11 OUT DROP\r\n");
        serial_write_str(uart_tx, "  /rules set 6 UDP_PORT 1000 TO 2000 INOUT NONE\r\n");
        serial_write_str(uart_tx, "  /rules set 7 TCP_PORT 80 TO 80 IN FORWARD\r\n");
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
    else if (strcmp(cmd, "/rules print\r\n") == 0)
    {
        config.update_cached_from_packet_handlers();
        while (! config.cache_valid())
            ;
        struct config if1 = config.retrieve(0);
        struct config if2 = config.retrieve(1);
        print_rules(uart_tx, if1, if2);
    }
    else if (strcmp(cmd, "/rules flush\r\n") == 0)
    {
        struct config cfg_main = config.get();
        for (int i=0; i<FW_NR_RULES; i++)
        {
            cfg_main.rules[i].valid = FW_RULE_INVALID;
        }
        config.set(cfg_main);
        serial_write_str(uart_tx, "rules flushed\r\n");
    }
    else if (strcmp(cmd, "/rules reset\r\n") == 0)
    {
        serial_write_str(uart_tx, "resetting counters\r\n");
    }
    else if (memmem(cmd, UART_RX_LINE_BUF_SIZE, "/rules swap", 11 ) == &cmd[0])
    {
        unsigned r1, r2;
        unsigned success = FALSE;

        unsafe
        {
            char cmd2[UART_RX_LINE_BUF_SIZE];
            char * unsafe token;
            char * unsafe savePtr;

            memcpy(cmd2, cmd, UART_RX_LINE_BUF_SIZE);

            if ((token = strtok_r(cmd2, " ", &savePtr)) != NULL)
            {
                if (strcmp((char * alias)token, "/rules") == 0)
                {
                    if ((token = strtok_r(NULL, " ", &savePtr)) != NULL)
                    {
                        if (strcmp((char * alias)token, "swap") == 0)
                        {
                            if ((token = strtok_r(NULL, " ", &savePtr)) != NULL)
                            {
                                r1 = strtol((char * alias)token, NULL, 10);

                                if ((token = strtok_r(NULL, " \r\n", &savePtr)) != NULL)
                                {
                                    r2 = strtol((char * alias)token, NULL, 10);
                                    success = TRUE;
                                }
                            }
                        }
                    }
                }
            }
        }

        if (r1 < 1 || r1 > FW_NR_RULES || r1 < 1 || r2 > FW_NR_RULES) success = FALSE;

        if (success)
        {
            struct config cfg_main = config.get();
            struct config temp;
            memcpy(&temp, &cfg_main.rules[r2-1], sizeof(struct rule));
            memcpy(&cfg_main.rules[r2-1], &cfg_main.rules[r1-1], sizeof(struct rule));
            memcpy(&cfg_main.rules[r1-1], &temp, sizeof(struct rule));
            config.set(cfg_main);
            serial_write_str(uart_tx, "swapped rules\r\n");
        }
        else
        {
            serial_write_str(uart_tx, "usage: /rules swap <rule1> <rule2>\r\n");
        }

    }
    else if (memmem(cmd, UART_RX_LINE_BUF_SIZE, "/rules set", 10 ) == &cmd[0])
    {
        char cmd2[UART_RX_LINE_BUF_SIZE];
        memcpy(cmd2, cmd, UART_RX_LINE_BUF_SIZE);
        struct config cfg_main = config.get();

        unsigned result = parse_rules_set(cmd2, cfg_main);

        if (result)
        {
            config.set(cfg_main);
            serial_write_str(uart_tx, "rule set\r\n");
        }
        else
        {
            serial_write_str(uart_tx, "usage: /rules set <nr> <type> [<cond>] <dir> <action>\r\n");
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

void print_rules(client uart_tx_buffered_if uart_tx, struct config &cfg1, struct config &cfg2)
{
    serial_write_str(uart_tx, "NUM TYPE       CONDITION                             DIR      ACTION     MATCH_IN MATCH_OUT MATCH_TOTAL\r\n");
    //                                        255.255.255.255 MASK 255.255.255.255
    for (int i = 0; i < FW_NR_RULES; i++)
    {
        char pbuf[120];
        char type[16];
        char cond[48];
        char dir[8];
        char action[8];
        unsigned packets_in, packets_out, packets_total;

        if (cfg1.rules[i].valid == FW_RULE_INVALID)
        {
            snprintf(pbuf, 100, "%u\r\n", i+1);
            serial_write_str(uart_tx, pbuf);
            continue;
        }

        switch (cfg1.rules[i].type)
        {
            case FW_TYPE_ALL:
                snprintf(type, 16, "ALL");
                snprintf(cond, 48, "");
                break;
            case FW_TYPE_ETH_ADDR:
                snprintf(type, 16, "ETH_ADDR");
                snprintf(cond, 48, "%.2X:%.2X:%.2X:%.2X:%.2X:%.2X", cfg1.rules[i].mac.addr[5], cfg1.rules[i].mac.addr[4], cfg1.rules[i].mac.addr[3], cfg1.rules[i].mac.addr[2], cfg1.rules[i].mac.addr[1], cfg1.rules[i].mac.addr[0]);
                break;
            case FW_TYPE_ETH_PROT:
                snprintf(type, 16, "ETH_PROT");
                switch (cfg1.rules[i].prot)
                {
                    case 0x0806:
                        snprintf(cond, 48, "0x%.4X (ARP)", cfg1.rules[i].prot);
                        break;
                    case 0x0800:
                        snprintf(cond, 48, "0x%.4X (IPV4)", cfg1.rules[i].prot);
                        break;
                    case 0x086DD:
                        snprintf(cond, 48, "0x%.4X (IPV6)", cfg1.rules[i].prot);
                        break;
                    default:
                        snprintf(cond, 48, "0x%.4X", cfg1.rules[i].prot);
                        break;
                }

                break;
            case FW_TYPE_IPV4_ADDR:
                snprintf(type, 16, "IPV4_ADDR");
                snprintf(cond, 48, "%u.%u.%u.%u MASK %u.%u.%u.%u", cfg1.rules[i].ip.addr[3], cfg1.rules[i].ip.addr[2], cfg1.rules[i].ip.addr[1], cfg1.rules[i].ip.addr[0], cfg1.rules[i].mask.addr[3], cfg1.rules[i].mask.addr[2], cfg1.rules[i].mask.addr[1], cfg1.rules[i].mask.addr[0] );
                break;
            case FW_TYPE_IPV4_PROT:
                snprintf(type, 16, "ETH_PROT");
                switch (cfg1.rules[i].prot)
                {
                    case 0x01:
                        snprintf(cond, 48, "0x%.2X (ICMP)", cfg1.rules[i].prot);
                        break;
                    case 0x11:
                        snprintf(cond, 48, "0x%.2X (UDP)", cfg1.rules[i].prot);
                        break;
                    case 0x06:
                        snprintf(cond, 48, "0x%.2X (TCP)", cfg1.rules[i].prot);
                        break;
                    default:
                        snprintf(cond, 48, "0x%.2X", cfg1.rules[i].prot);
                        break;
                }
                break;
            case FW_TYPE_TCP_PORT:
                snprintf(type, 16, "TCP_PORT");
                snprintf(cond, 48, "%u - %u", cfg1.rules[i].nport[0], cfg1.rules[i].nport[1]);
                break;
            case FW_TYPE_UDP_PORT:
                snprintf(type, 16, "UDP_PORT");
                snprintf(cond, 48, "%u - %u", cfg1.rules[i].nport[0], cfg1.rules[i].nport[1]);
                break;
        }

        switch (cfg1.rules[i].direction)
        {
            case FW_DIR_IN:
                snprintf(dir, 8, "IN");

                break;
            case FW_DIR_OUT:
                snprintf(dir, 8, "OUT");
                break;
            case FW_DIR_INOUT:
                snprintf(dir, 8, "INOUT");
                break;
        }

        packets_in = cfg2.rules[i].count;
        packets_out = cfg1.rules[i].count;
        packets_total = packets_in + packets_out;

        switch (cfg1.rules[i].action)
        {
            case FW_ACTION_DROP:
                snprintf(action, 8, "DROP");
                break;
            case FW_ACTION_FORWARD:
                snprintf(action, 8, "FORWARD");
                break;
            case FW_ACTION_NONE:
                snprintf(action, 8, "NONE");
                break;
        }

        snprintf(pbuf, 120, "%-3u %-10s %-37s %-8s %-10s %-8u %-9u %u\r\n", i+1, type, cond, dir, action, packets_in, packets_out, packets_total);
        serial_write_str(uart_tx, pbuf);

    }
}

#define NUM_TOKENS 10
#define TOKEN_SIZE 32
unsigned parse_rules_set(char cmd[], struct config &cfg)
{
    char tokens[NUM_TOKENS][TOKEN_SIZE];
    unsigned count = 0;
    unsigned rn; // rule number
    unsigned dir, action;

    unsafe
    {
        char * unsafe token;
        char * unsafe savePtr;

        if ((token = strtok_r(cmd, " ", &savePtr)) != NULL)
        {
            if (strcmp((char * alias)token, "/rules") == 0)
            {
                strncpy(tokens[count], (char * alias)token, TOKEN_SIZE);
                count++;
            }

            while (count < NUM_TOKENS && (token = strtok_r(NULL, " \r\n", &savePtr)) != NULL)
            {
                strncpy(tokens[count], (char * alias)token, TOKEN_SIZE);
                count++;
            }
        }
    }

    if (count < 6)
    {
        return FALSE;
    }

    if (strcmp(tokens[0], "/rules") != 0 || strcmp(tokens[1], "set") != 0)
    {
        return FALSE;
    }

    rn = strtol(tokens[2], NULL, 10);
    if (rn < 1 || rn > FW_NR_RULES) return FALSE;
    rn--;

    if (strcmp(tokens[3], "ALL") == 0)
    {
        if      (strcmp(tokens[4], "IN")    == 0) dir = FW_DIR_IN;
        else if (strcmp(tokens[4], "OUT")   == 0) dir = FW_DIR_OUT;
        else if (strcmp(tokens[4], "INOUT") == 0) dir = FW_DIR_INOUT;
        else return FALSE;

        if      (strcmp(tokens[5], "FORWARD") == 0) action = FW_ACTION_FORWARD;
        else if (strcmp(tokens[5], "DROP")    == 0) action = FW_ACTION_DROP;
        else if (strcmp(tokens[5], "NONE")    == 0) action = FW_ACTION_NONE;
        else return FALSE;

        cfg.rules[rn].type      = FW_TYPE_ALL;
        cfg.rules[rn].direction = dir;
        cfg.rules[rn].action    = action;
        cfg.rules[rn].count     = 0;
        cfg.rules[rn].valid     = !FW_RULE_INVALID;

        return TRUE;
    }
    else if (strcmp(tokens[3], "ETH_ADDR") == 0)
    {
        uint8_t mac_addr[6];
        unsigned segments = 0;

        if (count != 7) return FALSE;

        if      (strcmp(tokens[5], "IN")    == 0) dir = FW_DIR_IN;
        else if (strcmp(tokens[5], "OUT")   == 0) dir = FW_DIR_OUT;
        else if (strcmp(tokens[5], "INOUT") == 0) dir = FW_DIR_INOUT;
        else return FALSE;

        if      (strcmp(tokens[6], "FORWARD") == 0) action = FW_ACTION_FORWARD;
        else if (strcmp(tokens[6], "DROP")    == 0) action = FW_ACTION_DROP;
        else if (strcmp(tokens[6], "NONE")    == 0) action = FW_ACTION_NONE;
        else return FALSE;

        unsafe
        {
            char * unsafe token;
            char * unsafe savePtr;
            char seg[5] = "0x00";

            if ((token = strtok_r((char * alias)tokens[4], ":", &savePtr)) != NULL)
            {
                if (strlen((char * alias)token) != 2)
                {
                    return FALSE;
                }

                seg[2] = token[0];
                seg[3] = token[1];

                mac_addr[5] = strtol(seg, NULL, 0);
                segments++;

                while (segments < 6 && (token = strtok_r(NULL, ":", &savePtr)) != NULL)
                {
                    if (strlen((char * alias)token) != 2)
                    {
                        return FALSE;
                    }

                    seg[2] = token[0];
                    seg[3] = token[1];
                    mac_addr[5-segments] = strtol(seg, NULL, 0);
                    segments++;
                }

                if (segments != 6) return FALSE;
            }
        }

        cfg.rules[rn].type      = FW_TYPE_ETH_ADDR;
        for (int i=0; i<6; i++) cfg.rules[rn].mac.addr[i] = mac_addr[i];
        cfg.rules[rn].direction = dir;
        cfg.rules[rn].action    = action;
        cfg.rules[rn].count     = 0;
        cfg.rules[rn].valid     = !FW_RULE_INVALID;
        return TRUE;
    }
    else if (strcmp(tokens[3], "ETH_PROT") == 0)
    {
        if (count != 7) return FALSE;

        uint16_t prot;

        if      (strcmp(tokens[5], "IN")    == 0) dir = FW_DIR_IN;
        else if (strcmp(tokens[5], "OUT")   == 0) dir = FW_DIR_OUT;
        else if (strcmp(tokens[5], "INOUT") == 0) dir = FW_DIR_INOUT;
        else return FALSE;

        if      (strcmp(tokens[6], "FORWARD") == 0) action = FW_ACTION_FORWARD;
        else if (strcmp(tokens[6], "DROP")    == 0) action = FW_ACTION_DROP;
        else if (strcmp(tokens[6], "NONE")    == 0) action = FW_ACTION_NONE;
        else return FALSE;

        if      (strcmp(tokens[4], "ARP")  == 0) prot = 0x0806;
        else if (strcmp(tokens[4], "IPV4") == 0) prot = 0x0800;
        else if (strcmp(tokens[4], "IPV6") == 0) prot = 0x086DD;
        else prot = strtol(tokens[4], NULL, 0);

        cfg.rules[rn].type      = FW_TYPE_ETH_PROT;
        cfg.rules[rn].prot      = prot;
        cfg.rules[rn].direction = dir;
        cfg.rules[rn].action    = action;
        cfg.rules[rn].count     = 0;
        cfg.rules[rn].valid     = !FW_RULE_INVALID;
        return TRUE;
    }
    else if (strcmp(tokens[3], "IPV4_ADDR") == 0)
    {
        uint8_t ip_addr[4];
        unsigned segments = 0;

        if (count != 9) return FALSE;

        if      (strcmp(tokens[7], "IN")    == 0) dir = FW_DIR_IN;
        else if (strcmp(tokens[7], "OUT")   == 0) dir = FW_DIR_OUT;
        else if (strcmp(tokens[7], "INOUT") == 0) dir = FW_DIR_INOUT;
        else return FALSE;

        if      (strcmp(tokens[8], "FORWARD") == 0) action = FW_ACTION_FORWARD;
        else if (strcmp(tokens[8], "DROP")    == 0) action = FW_ACTION_DROP;
        else if (strcmp(tokens[8], "NONE")    == 0) action = FW_ACTION_NONE;
        else return FALSE;

        unsafe
        {
            char * unsafe token;
            char * unsafe savePtr;

            if ((token = strtok_r((char * alias)tokens[4], ".", &savePtr)) != NULL)
            {
                if (strlen((char * alias)token) > 3 || strlen((char * alias)token) < 1)
                {
                    return FALSE;
                }

                ip_addr[3] = strtol((char * alias)token, NULL, 10);
                segments++;

                while (segments < 4 && (token = strtok_r(NULL, ".", &savePtr)) != NULL)
                {
                    if (strlen((char * alias)token) > 3 || strlen((char * alias)token) < 1)
                    {
                        return FALSE;
                    }

                    ip_addr[3-segments] = strtol((char * alias)token, NULL, 0);
                    segments++;
                }

                if (segments != 4) return FALSE;
            }
        }

        for (int i=0; i<4; i++) cfg.rules[rn].ip.addr[i] = ip_addr[i];

        if (strcmp(tokens[5], "MASK")  != 0) return FALSE;

        segments = 0;
        unsafe
        {
            char * unsafe token;
            char * unsafe savePtr;

            if ((token = strtok_r((char * alias)tokens[6], ".", &savePtr)) != NULL)
            {
                if (strlen((char * alias)token) > 3 || strlen((char * alias)token) < 1)
                {
                    return FALSE;
                }

                ip_addr[3] = strtol((char * alias)token, NULL, 10);
                segments++;

                while (segments < 4 && (token = strtok_r(NULL, ".", &savePtr)) != NULL)
                {
                    if (strlen((char * alias)token) > 3 || strlen((char * alias)token) < 1)
                    {
                        return FALSE;
                    }

                    ip_addr[3-segments] = strtol((char * alias)token, NULL, 0);
                    segments++;
                }

                if (segments != 4) return FALSE;
            }
        }

        for (int i=0; i<4; i++) cfg.rules[rn].mask.addr[i] = ip_addr[i];

        cfg.rules[rn].type      = FW_TYPE_IPV4_ADDR;
        cfg.rules[rn].direction = dir;
        cfg.rules[rn].action    = action;
        cfg.rules[rn].count     = 0;
        cfg.rules[rn].valid     = !FW_RULE_INVALID;
        return TRUE;
    }
    else if (strcmp(tokens[3], "IPV4_PROT") == 0)
    {
        if (count != 7) return FALSE;

        uint16_t prot;

        if      (strcmp(tokens[5], "IN")    == 0) dir = FW_DIR_IN;
        else if (strcmp(tokens[5], "OUT")   == 0) dir = FW_DIR_OUT;
        else if (strcmp(tokens[5], "INOUT") == 0) dir = FW_DIR_INOUT;
        else return FALSE;

        if      (strcmp(tokens[6], "FORWARD") == 0) action = FW_ACTION_FORWARD;
        else if (strcmp(tokens[6], "DROP")    == 0) action = FW_ACTION_DROP;
        else if (strcmp(tokens[6], "NONE")    == 0) action = FW_ACTION_NONE;
        else return FALSE;

        if      (strcmp(tokens[4], "ICMP")  == 0) prot = 0x01;
        else if (strcmp(tokens[4], "UDP") == 0) prot = 0x11;
        else if (strcmp(tokens[4], "TCP") == 0) prot = 0x06;
        else prot = strtol(tokens[4], NULL, 0);

        cfg.rules[rn].type      = FW_TYPE_IPV4_PROT;
        cfg.rules[rn].prot      = prot;
        cfg.rules[rn].direction = dir;
        cfg.rules[rn].action    = action;
        cfg.rules[rn].count     = 0;
        cfg.rules[rn].valid     = !FW_RULE_INVALID;
        return TRUE;
    }
    else if (strcmp(tokens[3], "UDP_PORT") == 0)
    {
        if (count != 9) return FALSE;

        uint16_t port_s, port_e;

        if      (strcmp(tokens[7], "IN")    == 0) dir = FW_DIR_IN;
        else if (strcmp(tokens[7], "OUT")   == 0) dir = FW_DIR_OUT;
        else if (strcmp(tokens[7], "INOUT") == 0) dir = FW_DIR_INOUT;
        else return FALSE;

        if      (strcmp(tokens[8], "FORWARD") == 0) action = FW_ACTION_FORWARD;
        else if (strcmp(tokens[8], "DROP")    == 0) action = FW_ACTION_DROP;
        else if (strcmp(tokens[8], "NONE")    == 0) action = FW_ACTION_NONE;
        else return FALSE;

        port_s = strtol(tokens[4], NULL, 0);

        if (strcmp(tokens[5], "TO") != 0) return FALSE;

        port_e = strtol(tokens[6], NULL, 0);

        if (port_s > port_e) return FALSE;

        cfg.rules[rn].type      = FW_TYPE_UDP_PORT;
        cfg.rules[rn].nport[0]  = port_s;
        cfg.rules[rn].nport[1]  = port_e;
        cfg.rules[rn].direction = dir;
        cfg.rules[rn].action    = action;
        cfg.rules[rn].count     = 0;
        cfg.rules[rn].valid     = !FW_RULE_INVALID;
        return TRUE;
    }
    else if (strcmp(tokens[3], "TCP_PORT") == 0)
    {
        if (count != 9) return FALSE;

        uint16_t port_s, port_e;

        if      (strcmp(tokens[7], "IN")    == 0) dir = FW_DIR_IN;
        else if (strcmp(tokens[7], "OUT")   == 0) dir = FW_DIR_OUT;
        else if (strcmp(tokens[7], "INOUT") == 0) dir = FW_DIR_INOUT;
        else return FALSE;

        if      (strcmp(tokens[8], "FORWARD") == 0) action = FW_ACTION_FORWARD;
        else if (strcmp(tokens[8], "DROP")    == 0) action = FW_ACTION_DROP;
        else if (strcmp(tokens[8], "NONE")    == 0) action = FW_ACTION_NONE;
        else return FALSE;

        port_s = strtol(tokens[4], NULL, 0);

        if (strcmp(tokens[5], "TO") != 0) return FALSE;

        port_e = strtol(tokens[6], NULL, 0);

        if (port_s > port_e) return FALSE;

        cfg.rules[rn].type      = FW_TYPE_TCP_PORT;
        cfg.rules[rn].nport[0]  = port_s;
        cfg.rules[rn].nport[1]  = port_e;
        cfg.rules[rn].direction = dir;
        cfg.rules[rn].action    = action;
        cfg.rules[rn].count     = 0;
        cfg.rules[rn].valid     = !FW_RULE_INVALID;
        return TRUE;
    }

    return FALSE;
}
