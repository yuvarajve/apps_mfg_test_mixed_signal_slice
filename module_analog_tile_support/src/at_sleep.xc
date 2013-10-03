#include "at_sleep.h"
#include "debug_print.h"
#include "xassert.h"

//Scaling functions used within this module
static unsigned int convert_ms_to_ticks (unsigned int milliseconds){
  unsigned int read_val_32;
  unsigned long long ticks;
  read_node_config_reg(analog_tile, XS1_SU_CFG_SYS_CLK_FREQ_NUM, read_val_32); //read MHz setting
  read_val_32 = XS1_SU_CFG_SYS_CLK_FREQ(read_val_32);   //Mask off upper bits
  ticks = (unsigned long long) milliseconds * (unsigned long long) read_val_32 * 1000;
  return ticks;
}

static unsigned int convert_ticks_to_ms (unsigned long long ticks){
  unsigned int read_val_32;
  unsigned int milliseconds;
  read_node_config_reg(analog_tile, XS1_SU_CFG_SYS_CLK_FREQ_NUM, read_val_32); //read MHz setting
  read_val_32 = XS1_SU_CFG_SYS_CLK_FREQ(read_val_32);   //Mask off upper bits
  milliseconds = (unsigned int) (ticks / (1000 * read_val_32));
  return milliseconds;
}


//128B deep sleep memory access. These functions exepct char type. See at_sleep.h for macros
//that provide the type independant access to these (Ie. use struct, int, etc..)
void at_pm_memory_read_impl(unsigned char data[], unsigned char size){
  assert(size <= XS1_SU_NUM_GLX_PER_MEMORY_BYTE && msg("Read from sleep memory exceeds size"));
  read_periph_8 (analog_tile, XS1_SU_PER_MEMORY_CHANEND_NUM, XS1_SU_PER_MEMORY_BYTE_0_NUM,
      size, data);
}
void at_pm_memory_write_impl(unsigned char data[], unsigned char size){
    assert(size <= XS1_SU_NUM_GLX_PER_MEMORY_BYTE && msg("Write to sleep memory exceeds size"));
    write_periph_8 (analog_tile, XS1_SU_PER_MEMORY_CHANEND_NUM, XS1_SU_PER_MEMORY_BYTE_0_NUM,
      size, data);
}

char at_pm_memory_is_valid(void){
  char val[1];
  read_periph_8 (analog_tile, XS1_SU_PER_MEMORY_CHANEND_NUM, XS1_SU_PER_MEMORY_VALID_NUM, 1, val);
  if (val[0] == 0xed) return 1; 	//magic value for valid
  else return 0;
}

void at_pm_memory_validate(void){
  char val[1] = {0xed};     //magic value for valid
  write_periph_8 (analog_tile, XS1_SU_PER_MEMORY_CHANEND_NUM, XS1_SU_PER_MEMORY_VALID_NUM, 1, val);
}

void at_pm_memory_invalidate(void){
  char val[1] = {0x00};     //magic value for invalid
  write_periph_8 (analog_tile, XS1_SU_PER_MEMORY_CHANEND_NUM, XS1_SU_PER_MEMORY_VALID_NUM, 1, val);
}

//Sleep and wake control
void at_pm_enable_wake_source(at_wake_sources_t wake_source){
  unsigned int write_val;
  read_periph_32(analog_tile, XS1_SU_PER_PWR_CHANEND_NUM, XS1_SU_PER_PWR_MISC_CTRL_NUM, 1, &write_val);
  switch (wake_source){
    case RTC:
      write_val = XS1_SU_PWR_TMR_WAKEUP_64_SET(write_val, 1);   //Set timer to 64b mode
      write_val = XS1_SU_PWR_SLEEP_CLK_SEL_SET(write_val, 0);   //Use 31KHz source as clock for sleep
      write_val = XS1_SU_PWR_TMR_WAKEUP_EN_SET(write_val, 1);   //Enable timer wake
      break;

    case WAKE_PIN_LOW:
      write_val = XS1_SU_PWR_PIN_WAKEUP_EN_SET(write_val, 1);   //Enable pin wake
      write_val = XS1_SU_PWR_PIN_WAKEUP_ON_SET(write_val, 0);   //Wake on low level
      break;

    case WAKE_PIN_HIGH:
      write_val = XS1_SU_PWR_PIN_WAKEUP_EN_SET(write_val, 1);   //Disable pin wake
      write_val = XS1_SU_PWR_PIN_WAKEUP_ON_SET(write_val, 1);   //Wake on high level
      break;

    default:
       unreachable("Invalid wake source");
       break;
  }
  write_periph_32(analog_tile, XS1_SU_PER_PWR_CHANEND_NUM, XS1_SU_PER_PWR_MISC_CTRL_NUM, 1, &write_val);
}

void at_pm_disable_wake_source(at_wake_sources_t wake_source)
{
  unsigned int write_val;
  read_periph_32(analog_tile, XS1_SU_PER_PWR_CHANEND_NUM, XS1_SU_PER_PWR_MISC_CTRL_NUM, 1, &write_val);
  switch (wake_source){
    case RTC:
      write_val = XS1_SU_PWR_TMR_WAKEUP_64_SET(write_val, 1);   //Set timer to 64b mode
      write_val = XS1_SU_PWR_SLEEP_CLK_SEL_SET(write_val, 0);   //Use 31KHz source as clock for sleep
      write_val = XS1_SU_PWR_TMR_WAKEUP_EN_SET(write_val, 0);   //Disable timer wake
      break;

    case WAKE_PIN_LOW:
      write_val = XS1_SU_PWR_PIN_WAKEUP_EN_SET(write_val, 0);   //Disable pin wake
      write_val = XS1_SU_PWR_PIN_WAKEUP_ON_SET(write_val, 0);   //Wake on low level
      break;

    case WAKE_PIN_HIGH:
      write_val = XS1_SU_PWR_PIN_WAKEUP_EN_SET(write_val, 0);   //Disable pin wake
      write_val = XS1_SU_PWR_PIN_WAKEUP_ON_SET(write_val, 1);   //Wake on high level
      break;

    default:
       unreachable("Invalid wake source");
       break;
  }
  write_periph_32(analog_tile, XS1_SU_PER_PWR_CHANEND_NUM, XS1_SU_PER_PWR_MISC_CTRL_NUM, 1, &write_val);
}


void at_pm_sleep_now(void){
  timer t;
  unsigned char write_val, osc_good = 0;
  unsigned int read_val_32, write_val_32;
  int timeout, timenow;
  int crystal_si_osc_close = 0;                          //Indicates if frequencies are close
                                                         //If so, allows switching off of XTAL bias

  //Read MHz value and see if it is within %age of the on chip Si oscillator
  read_node_config_reg(analog_tile, XS1_SU_CFG_SYS_CLK_FREQ_NUM, read_val_32); //read MHz setting
  read_val_32 = XS1_SU_CFG_SYS_CLK_FREQ(read_val_32);   //Mask off upper bits
  if (((read_val_32 * (1024 + VCO_STEP_MAX * 10)) >> 10)  > SI_OSCILLATOR_FREQ_20M &&
      ((read_val_32 * (1024 - VCO_STEP_MAX * 10)) >> 10)  < SI_OSCILLATOR_FREQ_20M)
      crystal_si_osc_close = 1;

  if (crystal_si_osc_close){
    //Setup and enable 20MHz on chip oscilator
    write_val = XS1_SU_GEN_OSC_SEL_SET(0, 1);              //Ensure Si OSC is enabled
    write_val = XS1_SU_GEN_OSC_RST_EN_SET(write_val, 0);   //Select 20MHz osc
    write_periph_8(analog_tile, XS1_SU_PER_OSC_CHANEND_NUM, XS1_SU_PER_OSC_ON_SI_CTRL_NUM, 1, &write_val);

    //wait until oscillator is stable
    t :> timeout;
    timeout += (SI_OSC_STABILISATION * 100000);            //Max number of milliseconds to wait
    while (!osc_good){
      read_periph_32(analog_tile, XS1_SU_PER_PWR_CHANEND_NUM, XS1_SU_PER_PWR_PMU_DBG_NUM, 1, &read_val_32);
      osc_good = XS1_SU_PWR_ON_SI_STBL(read_val_32);
      t :> timenow;
      assert(timenow < timeout && msg("Si oscillator failed to settle within stablisation time"));
    }
  }

  //Disable all supplies except DC-DC2 (peripheral tile supply) during sleep mode
  write_val_32 = XS1_SU_PWR_EXT_CLK_MASK_SET(write_val_32, 0);  //Disable xCore clock
  write_val_32 = XS1_SU_PWR_VOUT1_EN_SET(write_val_32, 0);      //Disable DC-DC1
  write_val_32 = XS1_SU_PWR_VOUT1_MOD_SET(write_val_32, 0);     //Set to PWM mode
  write_val_32 = XS1_SU_PWR_VOUT2_EN_SET(write_val_32, 1);      //Enable DC-DC2
  write_val_32 = XS1_SU_PWR_VOUT2_MOD_SET(write_val_32, 1);     //Set to PFM mode
  write_val_32 = XS1_SU_PWR_VOUT5_EN_SET(write_val_32, 0);      //Disable LDO5
  write_val_32 = XS1_SU_PWR_VOUT6_EN_SET(write_val_32, 0);      //Disable LDO6
  write_periph_32(analog_tile, XS1_SU_PER_PWR_CHANEND_NUM, XS1_SU_PER_PWR_STATE_ASLEEP_NUM, 1, &write_val_32);

  if (crystal_si_osc_close){
    //Switch to silicon oscilator
    write_val = XS1_SU_GEN_OSC_RST_EN_SET(0, 0);           //Disable reset on clock change
    write_val = XS1_SU_GEN_OSC_SEL_SET(write_val, 1);      //Switch to silicon oscialtor
    write_periph_8(analog_tile, XS1_SU_PER_OSC_CHANEND_NUM, XS1_SU_PER_OSC_GEN_CTRL_NUM, 1, &write_val);

    //Disable XTAL bias and oscillator
    write_val = XS1_SU_XTAL_OSC_EN_SET(0, 0);              //Switch off crysal oscillator
    write_val = XS1_SU_XTAL_OSC_BIAS_EN_SET(write_val, 0); //Disable crystal bias circuit
    write_periph_8(analog_tile, XS1_SU_PER_OSC_CHANEND_NUM, XS1_SU_PER_OSC_XTAL_CTRL_NUM, 1, &write_val);
  }

  //go to sleep
  read_periph_32(analog_tile, XS1_SU_PER_PWR_CHANEND_NUM, XS1_SU_PER_PWR_MISC_CTRL_NUM, 1, &write_val_32);
  write_val_32 = XS1_SU_PWR_SLEEP_INIT_SET(write_val_32, 1);    //Initiate sleep bit
  write_periph_32(analog_tile, XS1_SU_PER_PWR_CHANEND_NUM, XS1_SU_PER_PWR_MISC_CTRL_NUM, 1, &write_val_32);
}

void at_pm_set_wake_time(unsigned int alarm_time){
  unsigned int write_val[2];
  unsigned long long alarm_ticks;
  alarm_ticks = convert_ms_to_ticks(alarm_time);
  write_val[0] = alarm_ticks & 0xFFFFFFFF;
  write_val[1] = alarm_ticks >> 32;
  write_periph_32(analog_tile, XS1_SU_PER_PWR_CHANEND_NUM, XS1_SU_PER_PWR_WAKEUP_TMR_LWR_NUM, 2, write_val);
}

void at_pm_set_min_sleep_time(unsigned int min_sleep_time){
  unsigned int write_val_32;
  unsigned int calc, bit_posn = 0;
  calc = ((min_sleep_time * SI_OSCILLATOR_FREQ_31K) / 1000); //sleep time in 31KHz sleep clock ticks
  for (int i = 0; i < 32; i++) if ((calc >> i) & 0x1) bit_posn = i; //perform an approximate log2 calculation
  read_periph_32(analog_tile, XS1_SU_PER_PWR_CHANEND_NUM, XS1_SU_PER_PWR_STATE_ASLEEP_NUM, 1, &write_val_32);
  write_val_32 = XS1_SU_PWR_INT_EXP_SET(write_val_32, bit_posn);
  write_periph_32(analog_tile, XS1_SU_PER_PWR_CHANEND_NUM, XS1_SU_PER_PWR_STATE_ASLEEP_NUM, 1, &write_val_32);
}

unsigned int at_rtc_read(void){
  unsigned int time_now[2] = {0, 0};
  unsigned long long ticks;
  read_periph_32(analog_tile, XS1_SU_PER_RTC_CHANEND_NUM, XS1_SU_PER_RTC_LWR_32BIT_NUM, 2, time_now);
  ticks = (unsigned long long) ((time_now[1] * 0x100000000) + time_now[0]);
  return convert_ticks_to_ms(ticks);
}

void at_rtc_reset(void){
  unsigned int time_now[2] = {0, 0};
  write_periph_32(analog_tile, XS1_SU_PER_RTC_CHANEND_NUM, XS1_SU_PER_RTC_LWR_32BIT_NUM, 2, time_now);
}

