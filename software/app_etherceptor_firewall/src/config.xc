#include <platform.h>
#include "config.h"
#include <quadflashlib.h>
#include <stdio.h>

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

void read_config(struct config *cfgPtr);
void write_config(struct config *cfgPtr);
unsigned config_crc(struct config *cfgPtr);

[[combinable]]
void config_handler(server interface config_if cfg_i[3])
{
    struct config cfg;

    struct config cached_cfg[2];
    unsigned pending_req = 0;
    unsigned req_type = REQ_UPDATE_CONFIG;

    read_config(&cfg);
    unsigned crc32 = config_crc(&cfg);
    if (cfg.crc32 != crc32)
    {
        for (int i =0; i < FW_NR_RULES; i++)
        {
            cfg.rules[i].valid = FW_RULE_INVALID;
        }
        cfg.crc32 = config_crc(&cfg);
        write_config(&cfg);
    }

    while (1)
    {
        select {
            case cfg_i[int i].get() -> struct config ret:
                ret = cfg;
                break;
            case cfg_i[int i].set(struct config arg_cfg):
                cfg = arg_cfg;
                cfg.crc32 = config_crc(&cfg);
                write_config(&cfg);
                req_type = REQ_UPDATE_CONFIG;
                cfg_i[0].update();
                cfg_i[1].update();
                break;
            case cfg_i[int i].update_cached_from_packet_handlers():
                req_type = REQ_SEND_CONFIG;
                cfg_i[0].update();
                cfg_i[1].update();
                pending_req = 2;
                break;
            case cfg_i[int i].send_config(struct config c):
                cached_cfg[i] = c;
                if (pending_req > 0) pending_req--;
                //printf("received config %u\n", i);
                break;
            case cfg_i[int i].cache_valid() -> unsigned ret:
                if (pending_req == 0) ret = 1;
                else ret = 0;
                break;
            case cfg_i[int i].retrieve(int iface) -> struct config ret:
                ret = cached_cfg[iface];
                break;
            case cfg_i[int i].get_req_type() -> unsigned ret:
                    ret = req_type;
                    break;
        }
    }

}

void read_config(struct config *cfgPtr)
{
    fl_connectToDevice(ports, deviceSpecs, sizeof(deviceSpecs)/sizeof(fl_QuadDeviceSpec));
    fl_readData(0, sizeof(struct config), (char *)cfgPtr);
    fl_disconnect();
}

void write_config(struct config *cfgPtr)
{
    unsigned char buf [16384];
    fl_connectToDevice(ports, deviceSpecs, sizeof(deviceSpecs)/sizeof(fl_QuadDeviceSpec));
    fl_writeData(0, sizeof(struct config), (char *)cfgPtr, buf);
    fl_disconnect();
}

unsigned config_crc(struct config *cfgPtr)
{
    unsigned *cfg = (unsigned *)cfgPtr;
    unsigned checksum = 0xFFFFFFFF;
    for (int i=0; i<(sizeof(struct config)/4)-1; i++)
    {
        crc32(checksum, cfg[i], 0xEDB88320);
    }

    return checksum;
}
