#include "pcap.h"
#include <stdio.h>
#include <string.h>
#include <syscall.h>
#include <print.h>
#include <quadflashlib.h>


char pcap_buf[PCAP_BUF_SIZE];
unsigned pcap_size = 0;
unsigned pending_not;
unsigned capturing = 0;
unsigned pcap_count = 0;

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

#define DELAY_100MS 10000000

void init_pcap_buf(char buf[], unsigned &fsize);
void write_pcap(char buf[], unsigned &fsize, unsigned &pcount);
void read_pcap(char buf[], unsigned &fsize, unsigned &pcount);

void pcap_handler(server interface pcap_if pcap[3])
{
    timer pcap_timer;
    unsigned pcap_timestamp, pcap_timestamp_int;
    unsigned pcap_time_s = 0;
    unsigned pcap_time_state = 0;

    read_pcap(pcap_buf, pcap_size, pcap_count);

    pcap_timer :> pcap_timestamp;
    pcap_timestamp_int = pcap_timestamp;
    while (1)
    {
        select {
            case pcap_timer when timerafter(pcap_timestamp_int + DELAY_100MS) :> void:
                pcap_timestamp_int += DELAY_100MS;
                pcap_time_state++;

                if ((pcap_time_state % 10) == 0)
                {
                    pcap_timestamp += (10 * DELAY_100MS);
                    pcap_time_s++;
                }
                break;
            case pcap[int i].start():
                init_pcap_buf(pcap_buf, pcap_size);
                pcap_count = 0;
                pending_not = PCAP_NOT_START_CAPTURE;
                pcap[0].update();
                pcap[1].update();
                pcap[2].update();
                break;
            case pcap[int i].stop():
                pending_not = PCAP_NOT_STOP_CAPTURE;
                pcap[0].update();
                pcap[1].update();
                pcap[2].update();

#if SAVE_PCAP_TO_HOST
                printf("captured: %u, size: %u\n", pcap_count, pcap_size);

                int fd = _open("capture.pcap", O_WRONLY | O_CREAT | O_TRUNC | O_BINARY, S_IREAD | S_IWRITE);
                if (fd == -1) {
                  printstrln("Error: _open failed");
                  _exit(1);
                }

                if (_write(fd, pcap_buf, pcap_size) != pcap_size) {
                  printstrln("Error: _write failed");
                  _exit(1);
                }

                if (_close(fd) != 0) {
                    printstrln("Error: _close failed.");
                    _exit(1);
                }
                printstrln("File written.");
#endif
                write_pcap(pcap_buf, pcap_size, pcap_count);
                break;
            case pcap[int i].erase():
                pcap_size = 0;
                pcap_count = 0;
                write_pcap(pcap_buf, pcap_size, pcap_count);
                break;
            case pcap[int i].full() -> unsigned ret:
                ret = (PCAP_BUF_SIZE - pcap_size) < 2000;
                if (ret && pending_not != PCAP_NOT_STOP_CAPTURE)
                {
                    pending_not = PCAP_NOT_STOP_CAPTURE;
                    pcap[0].update();
                    pcap[1].update();
                    pcap[2].update();
                    write_pcap(pcap_buf, pcap_size, pcap_count);
                }
                break;
            case pcap[int i].get_not_type() -> unsigned ret:
                ret = pending_not;
                break;
            case pcap[int i].capture(char packet[n], unsigned n):
                unsigned arrival_time;
                pcap_timer :> arrival_time;
                if ((PCAP_BUF_SIZE - pcap_size) > 2000)
                {
                    pcaprec_hdr_t hdr;
                    hdr.ts_sec = pcap_time_s;
                    hdr.ts_usec = (arrival_time - pcap_timestamp) / 100;
                    hdr.incl_len = n;
                    hdr.orig_len = n;

                    memcpy(&pcap_buf[pcap_size], &hdr, sizeof(pcaprec_hdr_t));
                    pcap_size += sizeof(pcaprec_hdr_t);

                    memcpy(&pcap_buf[pcap_size], packet, n);
                    pcap_size += n;

                    pcap_count++;
                }
                break;
            case pcap[int i].get_pcap_size() -> unsigned ret:
                ret = pcap_size;
                break;
            case pcap[int i].get_pcap_count() -> unsigned ret:
                ret = pcap_count;
                break;
            case pcap[int i].get_buf_byte(unsigned n) -> uint8_t ret:
                ret = 0;
                if (n < PCAP_BUF_SIZE)
                {
                    ret = pcap_buf[n];
                }
                break;
        }
    }
}

void init_pcap_buf(char buf[], unsigned &fsize)
{
    pcap_hdr_t file_hdr;
    file_hdr.magic_number  = 0xa1b2c3d4;
    file_hdr.version_major = 2;
    file_hdr.version_minor = 4;
    file_hdr.thiszone      = 0;
    file_hdr.sigfigs       = 0;
    file_hdr.snaplen       = 65535;
    file_hdr.network       = 0x01; // ethernet

    memcpy(&buf[0], &file_hdr, sizeof(pcap_hdr_t));
    fsize = sizeof(pcap_hdr_t);
}

void read_pcap(char buf[], unsigned &fsize, unsigned &pcount)
{
    fl_connectToDevice(ports, deviceSpecs, sizeof(deviceSpecs)/sizeof(fl_QuadDeviceSpec));
    fl_readData(0, sizeof(unsigned), (char *)&fsize);
    fl_readData(4, sizeof(unsigned), (char *)&pcount);

    if (fsize < PCAP_BUF_SIZE)
    {
        fl_readData(8, fsize, &buf[0]);
        if (buf[0] != 0xD4 || buf[1] != 0xC3 || buf[2] != 0xB2 || buf[3] != 0xA1)
        {
            fsize = 0;
            pcount = 0;
        }
    }
    else
    {
        fsize = 0;
        pcount = 0;
    }

    fl_disconnect();
}

void write_pcap(char buf[], unsigned &fsize, unsigned &pcount)
{
    unsigned char tempbuf [4096];
    if (fsize < PCAP_BUF_SIZE)
    {
        fl_connectToDevice(ports, deviceSpecs, sizeof(deviceSpecs)/sizeof(fl_QuadDeviceSpec));
        fl_writeData(0, sizeof(unsigned), (char *)&fsize, tempbuf);
        fl_writeData(4, sizeof(unsigned), (char *)&pcount, tempbuf);
        fl_writeData(8, fsize, (char *)&buf[0], tempbuf);
        fl_disconnect();
    }
}
