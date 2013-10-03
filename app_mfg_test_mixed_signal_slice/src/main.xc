/**
 * The copyrights, all other intellectual and industrial
 * property rights are retained by XMOS and/or its licensors.
 * Terms and conditions covering the use of this code can
 * be found in the Xmos End User License Agreement.
 *
 * Copyright XMOS Ltd 2013
 *
 * In the case where this code is a modification of existing code
 * under a separate license, the separate license terms are shown
 * below. The modifications to the code are still covered by the
 * copyright notice above.
 *
 **/

#include <xs1.h>
#include <xscope.h>
#include <xassert.h>
#include <stdio.h>
#include <syscall.h>
#include "platform.h"
#include "analog_tile_support.h"
#include "pwm_tutorial_example.h"
#include "print.h"

/****************************************************************************
 * Constants
 ***************************************************************************/
#define debounce_time        XS1_TIMER_HZ/50
#define BUTTON_PRESS_VALUE   0
#define PWM_PERIOD           200 // Set PWM period to 2us, 500KHz
#define pwm_duty_calc(x)     ((x * PWM_PERIOD) >> 8) //duty calc, 255 = full scale
#define ADC_TRIGGER_PERIOD   20000000 // 100ms for ADC trigger
#define ONE_SEC              100000000 // 1Sec
#define BLINK_DELAY          30000000
/****************************************************************************
 * Ports
 ***************************************************************************/
//Note that these assume use of XP-SKC-A16 + XA-SK-MIXED-SIGNAL hardware
on tile[0]: port trigger_port   = PORT_ADC_TRIGGER; //Port P32A bit 19 for XP
on tile[0]: port D042_spi_latch = XS1_PORT_8D;
on tile[0]: port pwm_1_dac_port = XS1_PORT_1G;      //XD22 PWM2 on mixed signal slice
on tile[0]: port pwm_2_dac_port = XS1_PORT_1B;
on tile[0]: port pushbutton_sw1 = XS1_PORT_1F;
on tile[0]: out port leds       = XS1_PORT_4E;
/****************************************************************************
 * Typedefs
 ***************************************************************************/
interface i_mxdsig_adc {
	unsigned char ms_adc0_ldr(void);
	unsigned char ms_adc1_therm(void);
    unsigned char ms_adc2_joystick(void);
    unsigned char ms_adc3_joystick(void);
    unsigned char ms_adc4_pwm(void);
    unsigned char ms_adc5_pwm(void);
    unsigned char ms_adc6_pwm(void);
    unsigned char ms_adc7_pwm(void);
};
typedef enum e_status{
	FAIL,
	PASS,
	ENABLE = 1
}e_status_t;
void xscope_user_init(void) {
   xscope_register(2,
           XSCOPE_CONTINUOUS, "0", XSCOPE_UINT, "0",
           XSCOPE_CONTINUOUS, "0", XSCOPE_UINT, "0");
   xscope_config_io(XSCOPE_IO_BASIC);
}

/****************************************************************************
 * Static Function
 ***************************************************************************/
static int TEMPERATURE_LUT[][2]= //Temperature Look up table
{
    {-10,211},{-5,202},{0,192},{5,180},{10,167},{15,154},{20,140},{25,126},{30,113},{35,100},
    {40,88},{45,77},{50,250},{55,230},{60,210}
};

static int linear_interpolation(int adc_value)
{
	int i=0,x1,y1,x2,y2,temper;
	while(adc_value<TEMPERATURE_LUT[i][1])
	{
		i++;
	}
	x1=TEMPERATURE_LUT[i-1][1];
	y1=TEMPERATURE_LUT[i-1][0];
	x2=TEMPERATURE_LUT[i][1];
	y2=TEMPERATURE_LUT[i][0];
	temper=y1+(((adc_value-x1)*(y2-y1))/(x2-x1));
	return temper;
}
/****************************************************************************
 * wait Function
 ***************************************************************************/
static void wait_1_sec(unsigned waitfor)
{
    unsigned int wait_tick;// = WAIT_TIME;
    timer t_wait;

    t_wait :> wait_tick;
    wait_tick += (ONE_SEC * waitfor);

	t_wait when timerafter(wait_tick):> void;

}
/****************************************************************************
 * sleep_wake_handler Function
 ***************************************************************************/
void sleep_wake_handler(void)
{
	char wokeup_from_sleep = 0;
	timer t;
	unsigned time;

	// If just woke up fom sleep, check sleep memory for any data
	if(at_pm_memory_is_valid())
	  {
	    // Read server configuration from sleep memory
	    at_pm_memory_read(wokeup_from_sleep);
	  }
	  else
	  {
	    // Write server configuration to sleep memory
	    at_pm_memory_write(wokeup_from_sleep);
	    at_pm_memory_validate();
	  }

	  if(wokeup_from_sleep == 1) {
	    // chip just woke up from sleep.. so blink leds and exit
		  t:> time;
		  for(int i=0;i<5;i++)
		  {
	         leds <: 0;
	         t when timerafter(time+BLINK_DELAY):> time;
	         leds <: 0xF;
	         t when timerafter(time+BLINK_DELAY):> time;
		  }

	    _exit(1);
	  }
}

/****************************************************************************
 * adc_pwm_dac Function
 ***************************************************************************/
void adc_pwm_dac(chanend c_pwm_1_dac,chanend c_pwm_2_dac)
{
	c_pwm_1_dac <: PWM_PERIOD;         //Set PWM period
	c_pwm_1_dac <: pwm_duty_calc(0);   //Set initial duty cycle
	c_pwm_2_dac <: PWM_PERIOD;         //Set PWM period
	c_pwm_2_dac <: pwm_duty_calc(0);   //Set initial duty cycle

	while (1)
	{
		c_pwm_1_dac <: pwm_duty_calc(50); //send to PWM
		c_pwm_2_dac <: pwm_duty_calc(50); //send to PWM
	}

	xassert(0 && _msg("Unreachable"));
}
/****************************************************************************
 * app_mfg_test_handler Function
 ***************************************************************************/
void app_mfg_test_handler(client interface i_mxdsig_adc ms_adc_c){

	unsigned button_press_1, button_press_2,timer_tick;
	timer debounce_timer;
	int button_state = 1;
	char usr_input;

	unsigned char button_1_status,thermistor_status,ldr_state=PASS;
	unsigned char ldr_status,joystick_status,adc4_status;
	unsigned char adc5_status,adc6_status,adc7_status;
	unsigned char overall_status;

	unsigned char adc0_value,adc1_value,adc2_value,adc3_value;
	unsigned char adc4_value,adc5_value,adc6_value,adc7_value;
	char wokeup_from_sleep = 1;

	printstr("Press Push Button SW1\n");

	D042_spi_latch <: 0xC0;
	pushbutton_sw1 :> button_press_1;
	set_port_drive_low(pushbutton_sw1);               // internal pull-down
	button_1_status = FAIL;

	while(1)
	{
        select
        {
        	case button_state => pushbutton_sw1 when pinsneq(button_press_1):> button_press_1: //checks if any button is pressed
        	{
        		button_1_status = 0;
        		debounce_timer :> timer_tick;
        		break;
        	}

        	case !button_1_status => debounce_timer when timerafter(timer_tick+debounce_time) :> void:
            {
        		pushbutton_sw1 :> button_press_2;
        		if(button_press_1 == button_press_2)
        		{
                    if(button_press_2 == BUTTON_PRESS_VALUE)
                    {
                    	button_1_status = PASS;
                        thermistor_status = FAIL;

                        adc1_value = ms_adc_c.ms_adc1_therm();

                        printstr("\nTemperature is :");printuint((linear_interpolation((int)adc1_value)));

                        printstr("\nPress 'P' if the displayed temperature is close to room temperature \notherwise press 'N' \nEnter Status:");
                        usr_input = getchar();
                        getchar();             // dummy to ready 'Enter' Key

                        while((usr_input != 'p') && (usr_input != 'P') && (usr_input != 'N') && (usr_input != 'n'))
                        {

                        	printstr("\nInvalid Option Given");
                        	printstr("\nPress 'P' or Press 'N' \nEnter Status:");
                        	usr_input = getchar();
                        	getchar();             // dummy to ready 'Enter' Key
                        }

                        if((usr_input == 'P') || (usr_input == 'p'))
                        {
                            thermistor_status = PASS;
                        }


                        {
                        	adc4_status = adc5_status = adc6_status = adc7_status = FAIL;
                        	printstr("\nConnect the jumper cables between the pwm outputs from header J4,J5 to ADC4,ADC5 lines of header J2 \nPress 'Enter'");
                        	getchar();    /**< Waiting for 'Enter' from tester will stall the running adc conversion,pwm */
                        	printstr("\nReading ADC....");
                        	wait_1_sec(4);
                        	wait_1_sec(6);    /**< This delay will make adc to read correct channels atleast once */

                        	adc4_value = ms_adc_c.ms_adc4_pwm();
                        	adc5_value = ms_adc_c.ms_adc5_pwm();

                        	adc4_status = ((adc4_value >= 47) && (adc4_value <= 52))?PASS:FAIL;
                        	adc5_status = ((adc5_value >= 47) && (adc5_value <= 52))?PASS:FAIL;

                        	printstr("\nADC4_PWM :");printuint(adc4_value);
                        	printstr("\nADC5_PWM :");printuint(adc5_value);

                        	printstr("\nConnect the jumper cables between the pwm outputs from header J4,J5 to ADC6,ADC7 lines of header J2 \nPress 'Enter'");
                        	getchar();    getchar();    /**< Waiting for 'Enter' from tester will stall the running adc conversion,pwm */
                        	printstr("\nReading ADC....");
                        	wait_1_sec(4);
                        	wait_1_sec(6);    /**< This delay will make adc to read correct channels atleast once */

                        	adc6_value = ms_adc_c.ms_adc6_pwm();
                        	adc7_value = ms_adc_c.ms_adc7_pwm();

                        	adc6_status = ((adc6_value >= 47) && (adc6_value <= 52))?PASS:FAIL;
                        	adc7_status = ((adc7_value >= 47) && (adc7_value <= 52))?PASS:FAIL;

                        	printstr("\nADC6_PWM :");printuint(adc6_value);
                        	printstr("\nADC7_PWM :");printuint(adc7_value);
                        }

                        {
                        	joystick_status = FAIL;
                        	adc2_value = ms_adc_c.ms_adc2_joystick();
                        	adc3_value = ms_adc_c.ms_adc3_joystick();
                        	printstr("\nADC2_JOYSTICK :");printuint(adc2_value);
                        	printstr("\nADC3_JOYSTICK :");printuint(adc3_value);
                        }

                        {
                        	ldr_status = FAIL;
                            adc0_value = ms_adc_c.ms_adc0_ldr();
                            ldr_state = (adc0_value >= 15)?PASS:FAIL;
                            ldr_status = ((adc0_value <= 3)&&(ldr_state==PASS))?PASS:FAIL;

                            printstr("\nADC0_LDR :");printuintln(adc0_value);
                        }

                        {
                        	printstr("\n------------------------------------------------");
                        	printstr("\n   MIXED SIGNAL SLICE MFG TEST SUMMARY RESULT");
                        	printstr("\n-------------------------------------------------\n");
                        	printstr("\n\tPush Button SW1 : "); printstr((button_1_status == PASS)?"PASS":"FAIL");
                        	printstr("\n\tThermistor      : "); printstr((thermistor_status == PASS)?"PASS":"FAIL");
                        	printstr("\n\tADC2            : "); printstr((joystick_status == PASS)?"PASS":"FAIL");
                        	printstr("\n\tADC3            : "); printstr((joystick_status == PASS)?"PASS":"FAIL");
                        	printstr("\n\tADC4            : "); printstr((adc4_status == PASS)?"PASS":"FAIL");
                        	printstr("\n\tADC5            : "); printstr((adc5_status == PASS)?"PASS":"FAIL");
                        	printstr("\n\tADC6            : "); printstr((adc6_status == PASS)?"PASS":"FAIL");
                        	printstr("\n\tADC7            : "); printstr((adc7_status == PASS)?"PASS":"FAIL");
                        	printstr("\n\tLDR             : "); printstr ((ldr_status == PASS)?"PASS":"FAIL");
                        }

                        {
                        	overall_status = button_1_status+thermistor_status+joystick_status+ldr_status;
                        	overall_status += adc4_status+adc5_status+adc6_status+adc7_status;

                        	if(overall_status == 8){

                        	    D042_spi_latch <: 0;
                        	    printstr("\nOverall Test 'PASSED'\nA16 Going to Sleep :-) !!!\n");
                        	    at_pm_memory_write(wokeup_from_sleep);
                        	    at_pm_memory_validate();
                        	    at_pm_enable_wake_source(WAKE_PIN_HIGH);
                        	    at_pm_sleep_now();
                        	}
                        }

                    } //if(button_press_2 == BUTTON_PRESS_VALUE)
        		} //if(button_press_1 == button_press_2)

        		button_1_status = 1;
        	    break;
            }

        } //select
	} //while(1)

	 xassert(0 && _msg("Unreachable"));
}
/****************************************************************************
 * app_adc_handler Function
 ***************************************************************************/
void app_adc_handler(server interface i_mxdsig_adc ms_adc_s,chanend c_adc)
{
	unsigned int adc_data[4] = { 0 },adc_value[8] = { 0 };
	int loop = 0;
	timer adc_trigger_timer;
	unsigned adc_trigger_time;
	at_adc_config_t adc_config = { { 0, 0, 0, 0, 0, 0, 0, 0 }, 0, 0, 0 };

	for(int idx = 0; idx < 8; idx++){
		adc_config.input_enable[idx] = ENABLE;
	}

	adc_config.bits_per_sample = ADC_8_BPS;
	adc_config.samples_per_packet = 4;
	adc_config.calibration_mode = 0;

	at_adc_enable(analog_tile, c_adc, trigger_port, adc_config);
	at_adc_trigger_packet(trigger_port, adc_config);

	adc_trigger_timer :> adc_trigger_time;         //Set timer for first loop tick
	adc_trigger_time += ADC_TRIGGER_PERIOD;

	while(1)
	{
		select
		{
            case adc_trigger_timer when timerafter(adc_trigger_time) :> void:
            {
            	at_adc_trigger_packet(trigger_port, adc_config);    //Trigger ADC
                adc_trigger_time += ADC_TRIGGER_PERIOD;
                break;
            } // case loop_timer to trigger adc

			case at_adc_read_packet(c_adc, adc_config, adc_data):
	        {
				adc_value[loop++] = adc_data[0];
				adc_value[loop++] = adc_data[1];
				adc_value[loop++] = adc_data[2];
				adc_value[loop++] = adc_data[3];
				loop = loop % 8;
				break;
	        }

			case ms_adc_s.ms_adc0_ldr() -> unsigned char return_val:
			     return_val = adc_value[0];
				 break;

			case ms_adc_s.ms_adc1_therm() -> unsigned char return_val:
                 return_val = adc_value[1];
			     break;

			case ms_adc_s.ms_adc2_joystick() -> unsigned char return_val:
				 return_val = adc_value[2];
			     break;

			case ms_adc_s.ms_adc3_joystick() -> unsigned char return_val:
			     return_val = adc_value[3];
				 break;

			case ms_adc_s.ms_adc4_pwm() -> unsigned char return_val:
			     return_val = adc_value[4];
				 break;

			case ms_adc_s.ms_adc5_pwm() -> unsigned char return_val:
			     return_val = adc_value[5];
				 break;

			case ms_adc_s.ms_adc6_pwm() -> unsigned char return_val:
			     return_val = adc_value[6];
				 break;

			case ms_adc_s.ms_adc7_pwm() -> unsigned char return_val:
			     return_val = adc_value[7];
				 break;

		}//select
	} //while(1)

	xassert(0 && _msg("Unreachable"));
}
/****************************************************************************
 * Main Function
 ***************************************************************************/
int main(void)
{
    interface i_mxdsig_adc i_ms_adc;
    chan chnl_pwm_1, chnl_pwm_2, chnl_adc;

    par{
    	on tile[0]: sleep_wake_handler();
    	on tile[0]: app_mfg_test_handler(i_ms_adc);
    	on tile[0]: app_adc_handler(i_ms_adc,chnl_adc);
    	on tile[0]: adc_pwm_dac(chnl_pwm_1,chnl_pwm_2);
    	on tile[0]: pwm_tutorial_example ( chnl_pwm_1, pwm_1_dac_port, 1);
    	on tile[0]: pwm_tutorial_example ( chnl_pwm_2, pwm_2_dac_port, 1);
    	xs1_a_adc_service(chnl_adc);
    }

	return 0;
}
