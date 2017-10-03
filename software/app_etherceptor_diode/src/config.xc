#include <platform.h>
#include "config.h"
#include <quadflashlib.h>

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

    read_config(&cfg);
    unsigned crc32 = config_crc(&cfg);
    if (cfg.crc32 != crc32)
    {
        cfg.forward_eth1 = 1;
        cfg.forward_eth2 = 0;
        cfg.allow_arp = 1;
        cfg.allow_icmp = 0;
        cfg.crc32 = config_crc(&cfg);
        write_config(&cfg);
    }

    cfg_i[0].update();
    cfg_i[1].update();

    while (1)
    {
        select {
            case cfg_i[int i].forward() -> unsigned ret:
                if (i==0) ret = cfg.forward_eth1;
                else if (i==1) ret = cfg.forward_eth2;
                else ret = 0;
                break;
            case cfg_i[int i].allow_arp() -> unsigned ret:
                ret = cfg.allow_arp;
                break;
            case cfg_i[int i].allow_icmp() -> unsigned ret:
                ret = cfg.allow_icmp;
                break;
            case cfg_i[int i].get_field(unsigned field) -> unsigned ret:
                switch (field)
                {
                    case STRUCT_FIELD_FORWARD_ETH1:
                        ret = cfg.forward_eth1;
                        break;
                    case STRUCT_FIELD_FORWARD_ETH2:
                        ret = cfg.forward_eth2;
                        break;
                    case STRUCT_FIELD_ALLOW_ARP:
                        ret = cfg.allow_arp;
                        break;
                    case STRUCT_FIELD_ALLOW_ICMP:
                        ret = cfg.allow_icmp;
                        break;
                    case STRUCT_FIELD_CRC32:
                        ret = cfg.crc32;
                        break;
                    default:
                        ret = 0xFFFFFFFF;
                        break;
                }
                break;
            case cfg_i[int i].set_field(unsigned field, unsigned value):
                switch (field)
                {
                    case STRUCT_FIELD_FORWARD_ETH1:
                        cfg.forward_eth1 = value;
                        break;
                    case STRUCT_FIELD_FORWARD_ETH2:
                        cfg.forward_eth2 = value;
                        break;
                    case STRUCT_FIELD_ALLOW_ARP:
                        cfg.allow_arp = value;
                        break;
                    case STRUCT_FIELD_ALLOW_ICMP:
                        cfg.allow_icmp = value;
                        break;
                    //case STRUCT_FIELD_CRC32:
                        //cfg.crc32 = value;
                        //break;
                }
                cfg_i[0].update();
                cfg_i[1].update();
                cfg.crc32 = config_crc(&cfg);
                write_config(&cfg);
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
