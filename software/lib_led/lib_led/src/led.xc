#include <platform.h>
#include "led.h"

#define FALSE 0
#define TRUE !FALSE

#define CHECK_TIME 20000
#define TIMER_MILLISECOND 100000
[[combinable]]
void led_handler(out port led_port, server interface led_if led_if)
{
    unsigned int blink_time = 3500000;
    int blink = FALSE;
    int blink_val = 0;
    int blink_enable = TRUE;
    timer btimer;
    timer btimer2;
    unsigned btime;
    unsigned btime2;
    unsigned blink_enable_countdown = 0;
    btimer :> btime;
    btimer2 :> btime2;
    unsigned timeout = CHECK_TIME;

    while (1)
    {
        select {
            case led_if.set_blink_time(unsigned int btime):
                blink_time = btime;
                break;
            case led_if.blink(unsigned amount):
                blink = amount;
                //blink_enable = TRUE;
                break;
            case led_if.led_on():
                led_port <: 1;
                blink_enable = FALSE;
                break;
            case led_if.led_off():
                led_port <: 0;
                blink_enable = FALSE;
                break;
            case led_if.blink_enable():
                blink_enable = TRUE;
                break;
            case led_if.blink_disable():
                blink_enable = FALSE;
                break;
            case led_if.blink_enable_after(unsigned ms):
                blink_enable_countdown = ms;
                break;
            case btimer when timerafter(btime + timeout) :> btime:
                if (!blink_enable)
                {
                    blink_val = 0;
                    blink = 0;
                    break;
                }
                if (blink_val == 1)
                {
                    blink_val = 0;
                    led_port <: 0;
                    timeout = blink_time;
                }
                else
                {
                    if (blink > 0)
                    {
                        blink_val = 1;
                        led_port <: 1;
                        blink--;
                        timeout = blink_time;
                    }
                    else
                    {
                        timeout = CHECK_TIME;
                    }
                }
                break;
            case btimer2 when timerafter(btime2 + TIMER_MILLISECOND) :> btime2:
                if (blink_enable_countdown > 0)
                {
                    blink_enable_countdown--;

                    if (blink_enable_countdown == 0)
                    {
                        blink_enable = TRUE;
                        led_port <: 0;
                    }
                }
                break;

        }
    }
}
