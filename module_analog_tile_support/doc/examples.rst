
Example Applications
====================

Demo Applications
-----------------

ADC to PWM Demo
+++++++++++++++

This simple application shows how the ADC can be used in conduction with a PWM generator (with filtered output) to create an analog loopback. An analog joystick provides a reference for an ADC input. The read value is then used to generate a PWM value, the filter output from which is read by a second ADC channel. Both values are displayed to observe if they track.

   * Package: sc_periph
   * Application: app_pwm_demo_a

Low-Power Ethernet Client Demo
++++++++++++++++++++++++++++++

This is demo uses the Sleep and Wake feature of A series XMOS devices. In this demo, a webclient running on the XMOS device informs a webserver running on a host workstation when it is going to sleep and has woken up from sleep. The XMOS device can be woken up using a periodic timer or pin connected to a comparator output from an LDR (light dependent resistor).

   * Package: sc_periph
   * Application: app_a16_slicekit_ethernet_sleep_wake_combo_demo

   ++Note to demonstrate entry AND exit from sleep mode, it is necessary to flash the application rather than just load it into RAM. This is because sleep mode removes the power from the xCORE and exit from sleep mode is a reset. Therefore to continue executing, the chip needs to boot from flash again.

Test Applications
-----------------

A number of test applications are included for completeness. Whilst not designed to be tutorial code, they may be useful to understand the library and chip capability, so are included for reference.

tests/test_adc_config
+++++++++++++++++++++

Test program that checks various configurations of the ADC, as well as the in-built calibration mode using the on-chip reference.

tests/test_sleep_a
++++++++++++++++++

Checks operation of deep sleep memory, accuracy of RTC when awake and initiates sleep mode.

tests/test_wdt_a
++++++++++++++++

Tests the operation of the WDT. Checks that the timer is accurate relative the xCORE reference clock and checks the API functions.

 
