#ifndef LED_H
#define LED_H

#include <platform.h>


interface led_if {
    void set_blink_time(unsigned btime);
    void blink(unsigned amount);
    void led_on();
    void led_off();
    void blink_enable();
    void blink_disable();
    void blink_enable_after(unsigned ms);
};

[[combinable]]
void led_handler(out port led_port, server interface led_if led_if);

#endif // LED_H
