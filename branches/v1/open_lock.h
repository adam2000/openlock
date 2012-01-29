// IO constants
#define RFID_IN_PIN			PORTBbits.RB0
#define INPUT_1_PIN			PORTBbits.RB1
#define INPUT_2_PIN			PORTBbits.RB2
#define RELAY_1_PIN			PORTBbits.RB3
#define RELAY_2_PIN			PORTBbits.RB4
#define LED_PIN					PORTBbits.RB5
#define TX_PIN					PORTCbits.RC6
#define RX_PIN					PORTCbits.RC7

#define TRIS_RFID_IN		TRISBbits.TRISB0
#define TRIS_INPUT_1		TRISBbits.TRISB1
#define TRIS_INPUT_2		TRISBbits.TRISB2
#define TRIS_RELAY_1		TRISBbits.TRISB3
#define TRIS_RELAY_2		TRISBbits.TRISB4
#define TRIS_LED				TRISBbits.TRISB5

#define TRIS_TX					TRISCbits.TRISC6
#define TRIS_RX					TRISCbits.TRISC7

// Protocol constants
#define RELAY_1_ON 'p'
#define RELAY_2_ON 'q'
#define RELAY_1_OFF 'r'
#define RELAY_2_OFF 's'
#define INPUT_1 't'
#define INPUT_2 'u'

#define TIMER0_RELOAD 0xda    // 416,6 us @ 20MHz
#define TIMER2_RELOAD 0x31		// 1 ms @ 8MHz

void sleep_ms(unsigned long ms);

static void high_priority_isr(void) __interrupt 1;
static void low_priority_isr(void) __interrupt 2;

void my_usart_open();

void led_debug();

// software uart
void receive_serial_byte(void);
