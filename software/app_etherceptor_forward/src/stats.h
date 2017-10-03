#ifndef STATS_H
#define STATS_H

#include <platform.h>

interface stats_if {
    unsigned rx_total();
    unsigned tx_total();
    void reset();
};

#endif // STATS_H
