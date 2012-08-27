#include <stdio.h>
#include <fcntl.h>		/* open(), O_RDWR */
#include <sys/ioctl.h>		/* ioctl(), TIOCMGET, TIOCM_CD, ... */
#include <unistd.h>

#define DEVICE "/dev/usb/tts/0"

/* according to EIA-232, RX and TX uses negative logic, i.e.
   0 is represented by +3 .. +12V and 1 is represented by -3 .. -12V
   the control lines use positive logic, so +3 .. +12V means "active"
   and -3 .. -12V means "inactive" */

int read_status_pins(int fd)
{
	int i;
	ioctl(fd, TIOCMGET, &i);

	if((i & TIOCM_CD) == TIOCM_CD) {		/* Pin DCD */
		printf("DCD = high (3..12V)\n");
	} else {
		printf("DCD = low (0..-12V)\n");
	}
/*
	if((i &amp; TIOCM_DSR) == TIOCM_DSR)	// Pin DSR
	if((i &amp; TIOCM_CTS) == TIOCM_CTS)	// Pin CTS
	if((i &amp; TIOCM_RI ) == TIOCM_RI)		// Pin RI
*/
	return 0;
}

int write_status_pins(int fd)
{
	int i = 0;
	i |= TIOCM_RTS; 	// Pin RTS wird aktiviert (12V)
	i |= TIOCM_DTR; 	// Pin DTR wird aktiviert (12V)
	ioctl(fd, TIOCMBIS, &i);
	i |= TIOCM_RTS; 	// Pin RTS wird deaktiviert (-12V)
	i |= TIOCM_DTR; 	// Pin DTR wird deaktiviert (-12V)
	ioctl(fd, TIOCMBIC, &i);
	return 0;
}

int set_tx_pin(int fd)
{
	return ioctl(fd, TIOCSBRK, NULL);
}

int clear_tx_pin(int fd)
{
	return ioctl(fd, TIOCCBRK, NULL);
}

int main(int argc, char **argv)
{
	int fd;

	if((fd=open("/dev/ttyUSB0", O_RDWR)) <= 0) {
		printf("couldn't open serial device %s\n", DEVICE);
		return 10;
	}
	
	while ( 1 == 1 ) {

		int i;
		ioctl(fd, TIOCMGET, &i);

		printf("TIOCM_CD");
		if((i & TIOCM_CD) == TIOCM_CD) {		/* Pin DCD */
			printf("+\n");
		} else {
			printf("-\n");
		}

		printf("TIOCM_DSR");
		if((i & TIOCM_DSR) == TIOCM_DSR) {		/* Pin DCD */
			printf("+\n");
		} else {
			printf("-\n");
		}

		printf("TIOCM_CTS");
		if((i & TIOCM_CTS) == TIOCM_CTS) {		/* Pin DCD */
			printf("+\n");
		} else {
			printf("-\n");
		}

		printf("TIOCM_RI");
		if((i & TIOCM_RI) == TIOCM_RI) {		/* Pin DCD */
			printf("+\n");
		} else {
			printf("-\n");
		}

		printf("\n");

		sleep( 1 );
	}



	/* put example testing code here */
	close(fd);
	return 0;
}
