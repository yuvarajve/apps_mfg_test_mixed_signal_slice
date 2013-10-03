.. _sec_api:

Analog tile API
===============

Port Configuration
++++++++++++++++++

The only port required by the analog tile library is the ADC trigger. This should be set to the I/O pin that is used to trigger the ADC_SAMPLE pin on the A-series device. This should be chosen by the user, and is required in all cases. Within this peripheral library, it is assumed that XD70 (Port 32A big 19) is used to trigger the ADC. 

ADC API 
-------

.. doxygenenum:: at_adc_bits_per_sample_t
.. doxygenstruct:: at_adc_config_t
.. doxygenfunction:: at_adc_enable
.. doxygenfunction:: at_adc_disable_all
.. doxygenfunction:: at_adc_trigger
.. doxygenfunction:: at_adc_trigger_packet
.. doxygenfunction:: at_adc_read
.. doxygenfunction:: at_adc_read_packet

WDT (Watchdog Timer) API
------------------------

.. doxygenfunction:: at_watchdog_enable
.. doxygenfunction:: at_watchdog_disable
.. doxygenfunction:: at_watchdog_set_timeout
.. doxygenfunction:: at_watchdog_kick

Sleep & RTC (Realtime Clock) API
--------------------------------

.. doxygenenum:: at_wake_sources_t
.. doxygenfunction:: at_pm_memory_read_impl
.. doxygenfunction:: at_pm_memory_write_impl
.. doxygenfunction:: at_pm_memory_is_valid
.. doxygenfunction:: at_pm_memory_validate
.. doxygenfunction:: at_pm_memory_invalidate
.. doxygenfunction:: at_pm_enable_wake_source
.. doxygenfunction:: at_pm_disable_wake_source
.. doxygenfunction:: at_pm_set_wake_time
.. doxygenfunction:: at_pm_set_min_sleep_time
.. doxygenfunction:: at_pm_sleep_now
.. doxygenfunction:: at_rtc_read
.. doxygenfunction:: at_rtc_reset