#include <pic18fregs.h>
#include <stdlib.h>
#include <stdio.h>
#include <usart.h>
#include "config.h"
#include "open_lock.h"

#define DEBUG

// Global variables
unsigned long timer_2;
volatile char c;

// soft uart stuff
#define BAUD_RATE		9200
unsigned char rdata;            // holds the serial byte that was received

void main(void) {
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

	timer_2 = 0;

	// set up interrupt and timers
	RCONbits.IPEN = 1;

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

	LED_PIN = 0;
	RELAY_1_PIN = 0;
	RELAY_2_PIN = 0;
	sleep_ms(2000);
//	sleep_ms(2);
	led_debug();
	my_usart_open();

	// enable rfid serial input	
	INTCONbits.INT0IE = 1;

	while (1) {
#ifdef DEBUG
		LED_PIN = RELAY_1_PIN | RELAY_2_PIN | INPUT_1_PIN | INPUT_2_PIN;
#endif
//		TX_PIN = RFID_IN_PIN;
		if (INPUT_1_PIN) {
			usart_putc(INPUT_1);
			usart_puts("\n");
		}
		if (INPUT_2_PIN) {
			// open door
			usart_puts(INPUT_2);
			usart_puts("\n");
			RELAY_1_PIN = 1;
			RELAY_2_PIN = 1;
		}
		else {
			RELAY_1_PIN = 0;
			RELAY_2_PIN = 0;
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
	if (INTCONbits.INT0IF) {
		INTCONbits.INT0IF = 0;		/* Clear Interrupt Flag */
		INTCONbits.INT0IE = 0;	// disable until stopbit received
		receive_serial_byte();
		usart_putc(rdata);
		usart_puts("\n");
	}
}

static void low_priority_isr(void) __interrupt 2 {
	if (PIR1bits.TMR2IF) {
		PR2 = TIMER2_RELOAD;		// 1 ms delay at 8 MHz
		PIR1bits.TMR2IF = 0;
		timer_2++;		
	}
	if (usart_drdy()) {
		LED_PIN = 1;
		// retransmit it
		c = usart_getc();
		usart_putc(c);
		
		switch (c) {
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

void my_usart_open() {
	SPBRG = 207;					// 8MHz => 9600 baud
//	SPBRG = 16;					// 8MHz => 115200 baud
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

// software uart
void receive_serial_byte(void) {
  unsigned char i, sleep_timer;
  unsigned char d[8];

	sleep_timer = 0;

	while (sleep_timer++ < 104);								// gives 157,6 uS ~1,5 baud - should be 156,250000000005

  for (i = 0; i < 8; i++) {
		// receive 8 serial bits, LSB first
		d[i] = !RFID_IN_PIN;
		
		sleep_timer = 0;

		if (i < 7) {
			while (sleep_timer++ < 69);              // gives 104 uS ~1 baud - should be 104,16666666667
		}
  }

	// convert to byte
	rdata = 0;
  for (i = 0; i < 8; i++) {
		rdata |= (d[i] << i);
	}
  
	sleep_timer = 0;
  while (sleep_timer++ < 59);              // wait for baud

	INTCONbits.INT0IE = 1;
}