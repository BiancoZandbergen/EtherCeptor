#ifndef PCAP_H
#define PCAP_H
#include <platform.h>
#include "ethernet.h"

#define PCAP_BUF_SIZE 125000

#define PCAP_NOT_START_CAPTURE 0
#define PCAP_NOT_STOP_CAPTURE  1

typedef struct pcap_hdr_s {
        uint32_t magic_number;   /* magic number */
        uint16_t version_major;  /* major version number */
        uint16_t version_minor;  /* minor version number */
        int32_t  thiszone;       /* GMT to local correction */
        uint32_t sigfigs;        /* accuracy of timestamps */
        uint32_t snaplen;        /* max length of captured packets, in octets */
        uint32_t network;        /* data link type */
} pcap_hdr_t;

typedef struct pcaprec_hdr_s {
        uint32_t ts_sec;         /* timestamp seconds */
        uint32_t ts_usec;        /* timestamp microseconds */
        uint32_t incl_len;       /* number of octets of packet saved in file */
        uint32_t orig_len;       /* actual length of packet */
} pcaprec_hdr_t;

interface pcap_if {
    unsigned full();
    void start();
    void stop();
    void erase();
    void capture(char packet[n], unsigned n);

    unsigned get_pcap_size();
    unsigned get_pcap_count();
    uint8_t get_buf_byte(unsigned n);

    [[notification]]
    slave void update();

    [[clears_notification]]
    unsigned get_not_type();
};


void pcap_handler(server interface pcap_if pcap[3]);

#endif // PCAP_H
