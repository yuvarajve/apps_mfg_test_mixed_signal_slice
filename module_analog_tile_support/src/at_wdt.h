#ifndef AT_WDT_H_
#define AT_WDT_H_

#include <xs1_su.h>
#include <platform.h>

//////////Watchdog timer//////////

/** Function that enables the watchdog timer. On overflow, it reset the xCORE
 * tile only. The analog tile is not reset.
 * By default, the WDT is disabled by the chip.
 */
void at_watchdog_enable(void);

/** Function that disables the watchdog timer.
 * By default, the WDT is disabled by the chip.
 *
 */
void at_watchdog_disable(void);

/** Function that sets the overflow time in milliseconds, from now.
 * Calling this function will automatically clear the WDT and start counting from zero ms.
 * It is a 16b counter which allows up to 65535 milliseconds, or about 65 seconds.
 *
 * \param milliseconds      watchdog overflow time in milliseconds
 */
void at_watchdog_set_timeout(unsigned short milliseconds);

/** Function that kicks the watchdog timer, Ie. sets it counting from zero.
 * This function should be periodically called to prevent overflow and system reset, during
 * normal operation.
 * It returns the current time in the watchdog timer, to allow the application to see
 * how close it is to a reset caused by WDT overflow
 *
 * \returns WDT time in milliseconds.
 */
unsigned short at_watchdog_kick(void);


#endif /* AT_WDT_H_ */
