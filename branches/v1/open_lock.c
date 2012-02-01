#include <pic18fregs.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <usart.h>
#include "config.h"
#include "open_lock.h"

#define DEBUG

#define RFID_LENGTH 10
#define COMMAND_LENGTH 10
#define MAX_USERS 20

// soft uart stuff
#define BAUD_RATE		9200
volatile unsigned char rfid[RFID_LENGTH + 1];
volatile unsigned char rfid_byte_index;
volatile unsigned char command[COMMAND_LENGTH + 1];
volatile unsigned char command_index;

volatile unsigned char users[MAX_USERS][RFID_LENGTH + 1];
volatile unsigned char users_num;
volatile unsigned char users_rfid_byte_index;

// Global variables
unsigned char open_door_state;
unsigned long timer_2;
volatile char c; //, last_c;

void main(void) {
	unsigned char i;
	OSCCONbits.SCS = 0x10;			// System Clock Select bits = External oscillator
	OSCCONbits.IRCF = 0x7;		// Internal Oscillator Frequency Select bits 8 MHz (INTOSC drives clock directly)

	TRIS_RFID_IN = 1;
	TRIS_INPUT_1 = 1;
	TRIS_INPUT_2 = 1;
	TRIS_RELAY_1 = 0;
	TRIS_RELAY_2 = 0;
	TRIS_LED = 0;

	TRIS_TX = 0;
	TRIS_RX = 1;

	open_door_state = 0;
	timer_2 = 0;
	command_index = 0;
	rfid_byte_index = 0;
	
	users_rfid_byte_index = 0;
	users_num = 0;

	LED_PIN = 0;
	RELAY_1_PIN = 0;
	RELAY_2_PIN = 0;

	// set up interrupt and timers
	RCONbits.IPEN = 1;
	
	INTCONbits.INT0IE = 1;
	INTCON2bits.INTEDG0 = 0;	// int on falling edge
	INTCONbits.INT0IF = 0;

	// timer 0
	T0CONbits.T0PS0 = 0;
	T0CONbits.T0PS1 = 0;
	T0CONbits.T0PS2 = 0;	// prescaler 1:2
	T0CONbits.TMR0ON = 0;
	T0CONbits.T08BIT = 1;	// use timer0 8-bit counter
	T0CONbits.T0CS = 0;		// internal clock source
	T0CONbits.PSA = 0;		// enable timer0 prescaler
	T0CONbits.TMR0ON = 1;	// enable timer0
	INTCONbits.T0IE = 0;

// timer 2
	T2CONbits.T2CKPS0 = 1;
	T2CONbits.T2CKPS1 = 0;
	T2CONbits.TOUTPS0 = 1;
	T2CONbits.TOUTPS1 = 0;
	T2CONbits.TOUTPS2 = 0;
	T2CONbits.TOUTPS3 = 1;
	IPR1bits.TMR2IP = 0;		// low priority
	T2CONbits.TMR2ON = 1;
	PIE1bits.TMR2IE = 1;
	PIR1bits.TMR2IF = 1;

	INTCONbits.PEIE = 1;
	INTCONbits.GIE = 1;	/* Enable Global interrupts   */	

	sleep_ms(2000);
	led_debug();

	my_usart_open();

	while (1) {
		if (rfid_byte_index >= RFID_LENGTH) {
			// when finished receiving...
			INTCONbits.INT0IE = 0;		// disable rfid interrupt
			rfid[RFID_LENGTH] = '\0';
			usart_puts(rfid);
			usart_puts("*\n");

			for (i = 0; i < users_num; i++) {
				if (strcmp(rfid, users[i]) == 0) {
					open_door();
				}
			}

			rfid_byte_index = 0;
			INTCONbits.INT0IE = 1;		// re-enable rfid interrupt
		}
		if (INPUT_1_PIN) {
			// door bell
			INTCONbits.INT0IE = 0;		// disable rfid interrupt
			usart_putc(INPUT_1);
			usart_puts("\n");
			INTCONbits.INT0IE = 1;		// re-enable rfid interrupt
		}
		if (INPUT_2_PIN) {
			open_door();
		}
		if (open_door_state) {
			open_door();
		}
	}
}

void sleep_ms(unsigned long ms) {
	unsigned long start_timer_2;
	start_timer_2 = timer_2;	

// while the absolute value of the time diff < ms
	while ( (((signed long)(timer_2 - start_timer_2) < 0) ? (-1 * (timer_2 - start_timer_2)) : (timer_2 - start_timer_2)) < ms) {
		// do nothing
	}
}

static void high_priority_isr(void) __interrupt 1 {
	unsigned char rdata;            // holds the serial byte that was received
  unsigned char counter;

	if (INTCONbits.INT0IF) {
		INTCONbits.INT0IF = 0;		/* Clear Interrupt Flag */
		INTCONbits.GIE = 0;	// disable until stopbit received
		INTCONbits.TMR0IF = 0;	/* Clear the Timer Flag  */
		TMR0L = (256 - SER_BAUD - 29);

		while (!INTCONbits.TMR0IF);								// gives 156,5 uS ~1,5 baud - should be 156,250000000005

		rdata = 0;
	  for (counter = 0; counter < 8; counter++) {
			// receive 8 serial bits, LSB first
			rdata |= RFID_IN_PIN << counter;
		
			INTCONbits.TMR0IF = 0;	/* Clear the Timer Flag  */
			TMR0L -= SER_BAUD;
			while (!INTCONbits.TMR0IF);
	  }
		rfid[rfid_byte_index++] = rdata;

		INTCONbits.TMR0IF = 0;	/* Clear the Timer Flag  */
		TMR0L -= SER_BAUD - 65;
		while (!INTCONbits.TMR0IF);

		INTCONbits.INT0IF = 0;
		INTCONbits.GIE = 1;	// re-enable
	}
}

static void low_priority_isr(void) __interrupt 2 {
	unsigned char counter;
	if (PIR1bits.TMR2IF) {
		PR2 = TIMER2_RELOAD;		// 1 ms delay at 8 MHz
		PIR1bits.TMR2IF = 0;
		timer_2++;		
#ifdef DEBUG
		LED_PIN = RELAY_1_PIN | RELAY_2_PIN | INPUT_1_PIN | INPUT_2_PIN;
#endif
	}
	if (usart_drdy()) {
//		INTCONbits.GIE = 0;	// disable until stopbit received
		c = usart_getc();
		
		if (c == '\n') {
			// end of command
			command[command_index - 1] = '\0';	// null terminate it
			command_index = 0;
			if (strlen(command) > 1) {
				// add rfid
				strcpy(users[users_num++], command);
			}
			else {
				// other commands
				switch (command[0]) {
					case DUMP_RFIDS:
						for (counter = 0; counter < users_num; counter++) {
							usart_puts(users[counter]);
							usart_puts("\n");
						}
						break;
					case FLUSH_RFIDS:
						users_num = 0;
						break;
					case OPEN_DOOR:
						//open_door_state = 1;		// ERROR: does not ever return...
						break;
					case RELAY_1_ON:
						RELAY_1_PIN = 1;
						break;
					case RELAY_2_ON:
						RELAY_2_PIN = 1;
						break;
					case RELAY_1_OFF:
						RELAY_1_PIN = 0;
						break;
					case RELAY_2_OFF:
						RELAY_2_PIN = 0;
						break;
				}
			}
			
		}
		else {
			// add character to command and check for overflow
			if (command_index <= COMMAND_LENGTH) {
				command[command_index] = c;
				command_index++;
			}
			else {
				command[COMMAND_LENGTH] = '\0';	// null terminate it
				command_index = 0;
				usart_puts("overflow\n");		
			}
		}
//		INTCONbits.GIE = 1;	// re-enable
	}
}

void my_usart_open() {
//	SPBRG = 207;					// 8MHz => 9600 baud
	SPBRG = 16;					// 8MHz => 115200 baud
	TXSTAbits.BRGH = 1;	// (1 = high speed)
	TXSTAbits.SYNC = 0;	// (0 = asynchronous)
	BAUDCONbits.BRG16 = 1;
	
	// SPEN - Serial Port Enable Bit 
	RCSTAbits.SPEN = 1; // (1 = serial port enabled)

	// TXIE - USART Transmit Interupt Enable Bit
	PIE1bits.TXIE = 0; // (1 = enabled)
	IPR1bits.TXIP = 0; // USART Tx on low priority interrupt

	// RCIE - USART Receive Interupt Enable Bit
	PIE1bits.RCIE = 1; // (1 = enabled)
	IPR1bits.RCIP = 0; // USART Rx on low priority interrupt
	
	// TX9 - 9-bit Transmit Enable Bit
	TXSTAbits.TX9 = 0; // (0 = 8-bit transmit)
	
	// RX9 - 9-bit Receive Enable Bit
	RCSTAbits.RX9 = 0; // (0 = 8-bit reception)
	
	// CREN - Continuous Receive Enable Bit
	RCSTAbits.CREN = 1; // (1 = Enables receiver)
	
	// TXEN - Trasmit Enable Bit
	TXSTAbits.TXEN = 1; // (1 = transmit enabled)
}

void led_debug() {
	sleep_ms(20);
	LED_PIN = 1;
	sleep_ms(80);
	LED_PIN = 0;
	sleep_ms(20);
}

void open_door() {
	// open door
	RELAY_1_PIN = 1;
	RELAY_2_PIN = 1;
	sleep_ms(DOOR_OPEN_TIME);

	RELAY_1_PIN = 0;
	RELAY_2_PIN = 0;
}