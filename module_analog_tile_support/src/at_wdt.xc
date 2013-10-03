#include "at_wdt.h"
#include "debug_print.h"
#include "xassert.h"

//Watchdog timer
void at_watchdog_enable(void){
  unsigned int write_val = 0x00000000; //Magic value ie. not 0x0D15AB1E
  write_node_config_reg(analog_tile, XS1_SU_CFG_WDOG_DISABLE_NUM, write_val);
}

void at_watchdog_disable(void){
  unsigned int write_val = 0x0D15AB1E; //Magic value to disable
  write_node_config_reg(analog_tile, XS1_SU_CFG_WDOG_DISABLE_NUM, write_val);
}


void at_watchdog_set_timeout(unsigned short milliseconds){
  unsigned int write_val;
  write_val = milliseconds | (~milliseconds << 16); //Set upper 16b to 1's complement of lower
                                                    //This is the 'password' for accessing reg
  write_node_config_reg(analog_tile, XS1_SU_CFG_WDOG_TMR_NUM, write_val); //write expiry value
}

unsigned short at_watchdog_kick(void){
  unsigned short expiry_val, wdt_timer;
  unsigned int write_val, read_val;
  read_node_config_reg(analog_tile, XS1_SU_CFG_WDOG_TMR_NUM, read_val);  //Get current expiry value & timer
  expiry_val = (unsigned short) XS1_SU_CFG_WDOG_EXP(read_val);           //mask off expiry value
  write_val =  (unsigned int) expiry_val | (~(unsigned int)expiry_val << 16);//Set the password in upper 16b
  wdt_timer = (unsigned short) XS1_SU_CFG_WDOG_TMR(read_val);            //mask off and shift timer value
  write_node_config_reg(analog_tile, XS1_SU_CFG_WDOG_TMR_NUM, write_val);//rewrite expiry value to reset timer
  return wdt_timer;                                                      //return wdt value
}
