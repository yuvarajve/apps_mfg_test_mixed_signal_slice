
Analog tile API Programming Guide
=================================

This section provides information on how to program applications using the Analog Tile module.

Source code structure
---------------------

Directory Structure
+++++++++++++++++++

A typical application using the analog tile support library will have at least two top level directories. The application will be contained in a directory starting with ``app_``, the analog tile support module source is in the ``module_analog_tile_support`` directory which contains library files required to build the application::
    
    app_[my_app_name]/
    module_analog_tile_support/

Of course the application may use other modules which can also be directories at this level. The modules compiled into the application are set by the ``USED_MODULES`` define in the application Makefile.

Key Files
+++++++++

The following header file contains prototypes of all functions required to use the LIN Bus 
module. The API is described in :ref:`sec_api`.

.. list-table:: Key Files
  :header-rows: 1

  * - File
    - Description
  * - ``analog_tile_support.h``
    - Analog tile API header file

The header file ``analog_tile_support.h`` includes the header files ``at_adc.h``, ``at_wdt.h`` and ``at_sleep.h``. If you are only calling sleep functions and not referencing the watchdog time and ADC, for example, it is OK to only include ``at_sleep.h``.

Module Usage
------------

Using the ADC
+++++++++++++

To setup the ADC within the application, the ADC needs to be configured and enabled and the ADC trigger port must be declared. 
The ADC peripheral is connected to the xCORE via an xCONNECT channel (link) which allows configuration and provides the data transfer. Consequently, the ADC looks like an extra core/task. This means it is declared within a ``par`` scope and is interfaced using a channel. This means events can also be triggered on receiving data from the ADC, just as you would a channel.

The minimal example below shows one ADC channel being configured and enabled (ADC_IN0) and a single sample being triggered and read::

  port trigger_port = PORT_ADC_TRIGGER; //Defined in at_adc.h	
  void adc_example(chanend c_adc)
  {
    unsigned short adc_result;
    at_adc_config_t adc_config = { { 0, 0, 0, 0, 0, 0, 0, 0 }, 0, 0, 0 }; //Initialise to all off
    adc_config.input_enable[0] = 1; //ADC_IN0
    adc_config.bits_per_sample = ADC_16_BPS;
    adc_config.samples_per_packet = 1;
    adc_config.calibration_mode = 0;
    at_adc_enable(usb_tile, c_adc, trigger_port, adc_config);

    at_adc_trigger(trigger_port); //Trigger the ADC!

    at_adc_read_packet(c_adc, adc_config, adc_result);
    printf("My ADC reads %x\n", adc_result);
  }

  int main() {
    chan c_adc;
    par {
      adc_example(c_adc);
      xs1_su_adc_service(c_adc);
    }
    return 0;
  }
 

Using Sleep Mode
++++++++++++++++

Sleep mode is a deep low power mode provided by the XS1-A series devices. In addition to low power modes within the xCORE such as Active Energy Conservation which allow figures of 10s of milliwatts, sleep mode allows a very low power state drawing hundreds of microwatts.

Sleep mode completely powers down the xCORE digital tile but keeps a few essential services going within the analog tile, such as RTC and sleep memory. 128 Bytes of deep sleep memory is provided that allows the application to store parameter before entering sleep mode. 

Sleep mode is entered using an API function call, and may be configured to be exited by the RTC clocked by the internal 31KHz (approx) silicon oscillator or an external pin (WAKE pin).

When the chip exits sleep mode, it does so via reset and cold reboot. Deep sleep memory allows the application to be steered according to state that was preserved before it went to sleep. Because exit from sleep mode takes tens of milliseconds (dependent on oscillator settling and firmware boot time), a typical minimum sleep/wake cycle is hundreds of milliseconds, but may be up to to multiple seconds, hours or more. The API 

The below example shows a minimal code snippet for entering sleep mode and waking up about 5s afterwards::

  void sleep_for_a_while(void)
  {
    at_rtc_reset();                   //Clear RTC to 0
    at_pm_set_wake_time(5000);	        //Wakeup in about 5 seconds
    at_pm_enable_wake_source(RTC);	//Wake on RTC
    at_pm_sleep_now();	               //Go to sleep
  }


In addition to sleep function, the chip also supports an RTC. Because xCORE devices have multiple, 10ns accurate timers available to the application, the RTC is typically only used for controlling the wakeup function. All RTC parameters are scaled to milliseconds by the library to make them easy to use. When awake, the RTC is clocked by the main chip oscillator. When asleep, the accuracy of the RTC is typically lower (see data sheet for specification) because it is clocked by the internal silicon oscillator which is susceptible to PVT variation. Consequently, it should be used to set an approximate wake up time only.

More detailed examples and use of sleep memory, as well as the RTC, can be found in the test and ``Example Applications`` section of this document and within the source tree.

	
Using the Watchdog Timer
++++++++++++++++++++++++

The Watchdog Timer provides a hardware mechanism to reset the xCORE should a software crash/lockup occur. The main application loop periodically "kicks" (resets) the WDT under normal operation.  The timeout period should be set higher than the typical loop speed, preventing reset under normal operation. The WDT API uses milliseconds as the time base and can support up to about a minute for before timeout.

Note that there is no mechanism for determining that the reset was caused by the WDT. We suggest using the deep sleep memory to periodically store system state to help determine the likely cause of the reset.

The below example shows a minimal code snippet for configuring the WDT to reset the chip after 500ms, should the functions take longer than expected to execute due to a software fault::

  void my_safe_function(void)
  {
    at_watchdog_set_timeout(500);   	//Set timeout period to 500ms
    at_watchdog_enable();
    at_watchdog_kick();			//Reset the watchdog counter
    while (1){
      foo();				//Functions that take less than 500ms
      bar();				//when operating correctly.
      at_watchdog_kick();
    }
  }				


Software Requirements
---------------------

This library is built with xTIMEcomposer Tools version 13.0.0. It can be used in version 13.0.0 or any higher version of xTIMEcomposer Tools.
