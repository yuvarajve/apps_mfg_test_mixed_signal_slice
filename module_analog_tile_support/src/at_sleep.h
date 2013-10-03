#ifndef AT_SLEEP_H_
#define AT_SLEEP_H_

#include <xs1_su.h>
#include <platform.h>

//Macro to allow arbitrary struct/array to be passed to sleep mem functions
//Uses XC cast (x, y) operation. See the _impl functions below also.
/**
 * Reads sleep memory and copies to array/structure up to 128B
 *
 * \param x      Structure or array that sleep memory is copied too
 */
#define at_pm_memory_read(x) at_pm_memory_read_impl((x, char[]), sizeof(x))

/**
 * Reads sleep memory and copies to array/structure up to 128B
 *
 * \param x      Structure or array that is copied into sleep memory 
 */
#define at_pm_memory_write(x) at_pm_memory_write_impl((x, char[]), sizeof(x))


/**
 * Approximate speed of 31KHz on chip silicon oscilator in Hz
 */
#define SI_OSCILLATOR_FREQ_31K 31250

/**
 * Approximate speed of 20MHz on chip silicon oscilator in MHz
 */
#define SI_OSCILLATOR_FREQ_20M 20

/**
 * Max stabilisation time of 20MHz oscillator in milliseconds Approximate speed of 31KHz on chip silicon oscilator in Hz
 */
#define SI_OSC_STABILISATION   15       

/**
 * Maximum percetage change of VCO. Used in sleep mode to see if XTAL and 20MHz OSC are close enough
 * to allow switch between clock sources without reset. If close enough, XTAL can be switched off.
 */
#define VCO_STEP_MAX           30

/** Enumerated type containing possible wake sources from sleep mode
 *
 * Each source type can be enabled or disabled.
 * RTC and WAKE_PIN_x may be used together however,
 * WAKE_PIN_LOW or HIGH are mutually exclusive. Ie. enabling wake
 * on WAKE_PIN_LOW will disable WAKE_PIN_HIGH
 */
typedef enum  {
    RTC,            /**<Enable wake from RTC*/
    WAKE_PIN_LOW,   /**<Wake when wake pin is low*/
    WAKE_PIN_HIGH}  /**<Wake when wake pin is high*/
at_wake_sources_t;


/** Function that writes an array of size up to 128B to sleep memory.
 * This is the worker function that copies the array from the sleep memory.
 * Note, to pass types other than char[], please use at_pm_memory_read(x) 
 * which is a macro that first casts the passed variable to char before 
 * calling this function.
 *
 * \param data      reference to the charater array to be written
 *
 * \param size      size of array to be written in bytes
 */
void at_pm_memory_read_impl(char data[], unsigned char size);

/** Function that writes an array of size up to 128B from sleep memory.
 * This is the worker function that copies the array to the sleep memory.
 * Note, to pass types other than char[], please use at_pm_memory_write(x)
 * which is a macro that first casts the passed variable to char before
 * calling this function.
 *
 * \param data      reference to the charater array to be written
 *
 * \param size      size of array to be written in bytes
 */
void at_pm_memory_write_impl(char data[], unsigned char size);

/** Function that test to see if the deep sleep memory contents are valid.
 *  Use before reading sleep memory to see if it has been previously initialised.
 *  Note that the chip initialises this to zero on reset.
 *
 * \returns boolean result. 1 = Valid, 0 = Invalid.
 */
char at_pm_memory_is_valid(void);

/** Function that sets the validity of the sleep memory to valid
 * Use only after a write to sleep memory contents.
 * Note that it defaults to invalid on reset.
 *
 */
void at_pm_memory_validate(void);

/** Function that sets the validity of the sleep memory to invalid
 * Note that it defaults to invalid after power-on reset.
 *
 */
void at_pm_memory_invalidate(void);

/** Function that enables the chip to be woken by specific sources
 * Each wake source type can be enabled or disabled.
 * RTC and WAKE_PIN_x may be used together however,
 * WAKE_PIN_LOW or HIGH are mutually exclusive. Ie. enabling wake
 * on WAKE_PIN_LOW will disable WAKE_PIN_HIGH and vice versa.
 * A single wake source can only be passed at a time. To enable multiple sources,
 * please call the function multiple times for each wake source.
 *
 * \param wake_source   enumerated type at_wake_sources_t specifying wake source to enable
 */
void at_pm_enable_wake_source(at_wake_sources_t wake_source);

/** Function that disables the chip to be woken by specific sources
 * Each wake source type can be enabled or disabled.
 * Disabling either WAKE_PIN_LOW or WAKE_PIN_HIGH will have the same
 * effect of diabling wake from pin.
 * A single wake source can only be passed at a time. To enable multiple sources,
 * please call the function multiple times for each wake source.
 *
 * \param wake_source   enumerated type at_wake_sources_t specifying wake source to disable
 */
void at_pm_disable_wake_source(at_wake_sources_t wake_source);

/** Function that sets the wake time in milliseconds, measured by the RTC clock.
 * It is recommended to reset the RTC before setting the wake time
 * to avoid issues with overflow if the application has been running
 * for some time before.
 * The time may be up to about 4E6 seconds from reset, or approx 48 days
 * before overflow occurs.
 *
 * \param alarm_time     absolute time to set alarm/wake up in milliseconds
 */
void at_pm_set_wake_time(unsigned int alarm_time);

/** Function that sets the minimum time to stay asleep in milliseconds.
 * Default time on power up is 2^16 sleep clocks, or about 2s.
 * Note this function truncates to the value to the nearest
 * power of 2, so is +100% - 50% accurate, due to hardware.
 * This setting is not critical but can be used, for example,
 * to ignore pin events until a certain time.
 *
 * \param min_sleep_time   minimum time asleep in milliseconds
 */
void at_pm_set_min_sleep_time(unsigned int min_sleep_time);

/** Function that instructs the chip to go to sleep immediately.
 * Sleep is a very deep state that switches off everything except
 * the RTC and deep sleep memory, so the application should have exited
 * gracefully before this function is called, including all peripheral functions.
 * This must be the last function to be called before sleep. When waking, the
 * chip will go through the reset sequence. Use deep sleep memory to
 * steer the application at boot time, to recover from sleep, and determine state.
 *
 */
void at_pm_sleep_now(void);

/** Function that reads the rtc value.
 * Takes the counter and scales to milliseconds.
 * The time may be up to about 4E6 seconds from reset, or approx 48 days
 * before overflow occurs.
 *
 * \return time in milliseconds.
 */
unsigned int at_rtc_read(void);

/** Function that clears the rtc value.
 * Sets the time to zero.
 */
void at_rtc_reset(void);


#endif /* AT_SLEEP_H_ */
