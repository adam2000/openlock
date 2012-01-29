
static __code char __at(__CONFIG1L) conf1L = _PLLDIV_DIVIDE_BY_5__20MHZ_INPUT__1L &
					     _CPUDIV__OSC1_OSC2_SRC___1__96MHZ_PLL_SRC___2__1L &
					     _USBPLL_CLOCK_SRC_FROM_OSC1_OSC2_1L;

static __code char __at(__CONFIG1H) conf1H = _OSC_INTOSC__USB_HS_1H &
					     _FCMEN_OFF_1H &
					     _IESO_OFF_1H;

static __code char __at(__CONFIG2L) conf2L = _PUT_OFF_2L &
					     _BODEN_ON_2L &
					     _BODENV_2_7V_2L &
					     _VREGEN_ON_2L;

static __code char __at(__CONFIG2H) conf2H = _WDT_DISABLED_CONTROLLED_2H;

static __code char __at(__CONFIG3H) conf3H = _MCLRE_MCLR_ON_RE3_OFF_3H &
					     _LPT1OSC_OFF_3H &
					     _PBADEN_PORTB_4_0__CONFIGURED_AS_DIGITAL_I_O_ON_RESET_3H &
					     _CCP2MUX_RB3_3H;

static __code char __at(__CONFIG4L) conf4L = _STVR_ON_4L &
					     _LVP_OFF_4L &
					     _ENICPORT_OFF_4L &
					     _ENHCPU_OFF_4L;

static __code char __at(__CONFIG5L) conf5L = _CP_0_OFF_5L & 
					     _CP_1_OFF_5L &
					     _CP_2_OFF_5L &
					     _CP_3_OFF_5L;


static __code char __at(__CONFIG5H) conf5H = _CPB_OFF_5H & _CPD_OFF_5H;

static __code char __at(__CONFIG6L) conf6L = _WRT_0_OFF_6L &
					     _WRT_1_OFF_6L &
					     _WRT_2_OFF_6L &
					     _WRT_3_OFF_6L;

static __code char __at(__CONFIG6H) conf6H = _WRTB_OFF_6H &
					     _WRTC_OFF_6H &
					     _WRTD_OFF_6H;

static __code char __at(__CONFIG7L) conf7L = _EBTR_0_OFF_7L &
					     _EBTR_1_OFF_7L &
					     _EBTR_2_OFF_7L &
					     _EBTR_3_OFF_7L;

static __code char __at(__CONFIG7H) conf7H = _EBTRB_OFF_7H;

