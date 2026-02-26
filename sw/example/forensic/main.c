
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
// #include <eembc_adaptation.h> // provides parse_args_from_stdin_csv, th_exit

// uart_gpio can communicate with another microcontroller through function like: 
// uart_gpio_puts, uart_gpio_can_send, uart_gpio_data_available, uart_gpio_getchar, uart_gpio_putchar, uart_gpio_printf, uart_gpio_scanf
// in the past it was used for communicating with Esp32 display for ECG project.
// Now it can be used to communicate with Esp32 display that acts as a login screen.
// #include <uart_gpio.h>     
// #include <uart_pynq.h>
// #include <sensors.h>       // analog_inputs, digital_inputs
// #include <utils_flute.h>   // wait_ms, wait_s, CLK_SPEED, get_ticks_count, get_overlay_ticks_count, get_random_number
#include <stdbool.h>

#include <neorv32.h>

#define CORRECT_PASSWORD "1234"

#define BAUD_RATE_0 19200
#define BAUD_RATE_1 115200

// __attribute__((used)) static void dummy() {
//     // to prevent linker from optimizing out the functions we need for the attack
//     neorv32_spi_available();
//     neorv32_spi_setup(0, 0, 0, 0);
//     neorv32_spi_disable();
//     neorv32_spi_cs_en(0);
//     neorv32_spi_transfer(0);
// }

// __attribute__((weak)) int _read(int file, char *ptr, int len)
// {
// 	int DataIdx;

// 	for (DataIdx = 0; DataIdx < len; DataIdx++)
// 	{
// 		// *ptr++ = __io_getchar();
// 		// *ptr++ = uart_pynq_getchar();
//         *ptr++ = neorv32_uart0_getc();
// 	}

// return len;
// }

// __attribute__((weak)) int _write(int file, char *ptr, int len)
// {
// 	int DataIdx;

// 	for (DataIdx = 0; DataIdx < len; DataIdx++)
// 	{
// 		// __io_putchar(*ptr++);
// 		// uart_pynq_putchar(*ptr++);
//         neorv32_uart0_putc(*ptr++);
// 		//ITM_SendChar(*ptr++);
// 	}
// 	return len;
// }

// UART_0 - is for pynq communication (SQL database queries)
// UART_1 - is for uart_gpio communication (Esp32 display board, keyboard, barcode scanner IDs)

void print_variable_address(uint32_t address, char *var_name);


void neorv32_uart_gets(neorv32_uart_t *UARTx, char *buffer) {
    int idx = 0;
    char c;

    // print_variable_address((uint32_t)buffer, "buffer");
    while (1) {
        while (!neorv32_uart_char_received(UARTx)) {
            // wait for data
        }
        c = neorv32_uart_getc(UARTx);
        /* neorv32_uart0_putc(c); */
        /* neorv32_uart0_puts("\nbuffer: "); */
        /* neorv32_uart0_puts(buffer); */
        /* neorv32_uart0_puts("\n"); */

        /* neorv32_uart0_putc(c); */
        /* neorv32_uart0_putc('\n'); */


        /* neorv32_uart0_puts("idx: "); */
        /* neorv32_uart0_putc('0' + (char)idx); */
        /* neorv32_uart0_puts("\n"); */
        if (c == '\n' || c == '\r') {
            buffer[idx] = '\0';
            break;
        } else {
            buffer[idx++] = c;
        }
    }
}

int neorv32_uart_sscanf(char *input, const char *format, ...) {
    char buffer[256];
    strncpy(buffer, input, sizeof(buffer));
    va_list args;
    va_start(args, format);
    int ret = vsscanf(buffer, format, args);
    va_end(args);
    return ret;
}

void wait_ms(uint32_t ms) {
    uint64_t cycles_to_wait = ((uint64_t)100000000 / 1000) * ms;
    uint64_t start = neorv32_cpu_get_cycle();
    while ((neorv32_cpu_get_cycle() - start) < cycles_to_wait);
}

// NEORV32_UART0, NEORV32_UART1 - constants (to be used as first argument of neorv32_uart_xxx functions)

bool is_barcode_known(char *barcode_str);
bool is_barcode_valid(unsigned long long barcode);
bool is_ean13_barcode(unsigned long long barcode);
bool is_upca_barcode(unsigned long long barcode);
unsigned long long barcode_str_to_num(char *barcode_str);

void print_variable_address(uint32_t address, char *var_name) {
    // custom implementation because neorv32 is wrong
    // use neorv32_uart0_putc instead of printf
    for (int i = 0; i < strlen(var_name); i++) {
        neorv32_uart0_putc(var_name[i]);
    }
    neorv32_uart0_puts(" address: 0x");
    for (int i = (sizeof(uint32_t) * 2) - 1; i >= 0; i--) {
        uint8_t nibble = (address >> (i * 4)) & 0x0F;
        char hex_char;
        if (nibble < 10) {
            hex_char = '0' + nibble;
        } else {
            hex_char = 'A' + (nibble - 10);
        }
        neorv32_uart0_putc(hex_char);
    }
    neorv32_uart0_puts("\n");
}

void main(void) {

    // cmd receives keyboard input and barcodes using the same uart_gpio interface 
    // (from the Esp32-based display board), it is used for:
    // - receiving password
    // - receiving barcodes
    // - logout from barcode scanning (access control) part of the program (back into login screen)
    char cmd[64] = {0};
    char *barcode_str = cmd;
    char login_buffer[32] = {0};
    

    // vulnerable password buffer
    char password_buffer[4] = "abc";

    // to increase needed password length to overwrite is_authorized 
    // (typing 5 chars instead of 4 looks more like a mistake than a hack attempt)
    // volatile is to prevent compiler from optimizing it out
    volatile int dummy_variable = 0; 

    // variable responsible for admin login authorization
    int is_authorized = 0;

    // __libc_init_array();
    // // without 2 lines below, printf worked only if it had "\n" character
    // setbuf(stdout, NULL);
    // setbuf(stdin, NULL);

    neorv32_rte_setup();
    // setup UART at default baud rate, no interrupts
    neorv32_uart0_setup(BAUD_RATE_0, 0);
    neorv32_uart1_setup(BAUD_RATE_1, 0);
    // print project logo via UART
    // neorv32_aux_print_logo();
    // say hello
    neorv32_uart0_puts("Hello world! :)\n");
    // printf("Hello world! :)\n");

    neorv32_uart0_puts("Password buffer initial content: '");
    neorv32_uart0_puts(password_buffer);
    neorv32_uart0_puts("'\n");

    // char msg[256]; 
    // sprintf(msg, "address diffference between password_buffer and is_authorized: %lld", 
    //     (long long)password_buffer - (long long)&is_authorized);
    // neorv32_uart0_puts(msg);
    // sprintf(msg, "address diffference between password_buffer and dummy_variable: %lld", 
    //     (long long)password_buffer - (long long)&dummy_variable);
    // neorv32_uart0_puts(msg);
    // // neorv32_uart_printf implementation is limited and doesn't support "%lld"

    // printf("address difference between password_buffer and is_authorized: %lld\n", (long long)password_buffer - (long long)&is_authorized);
    // printf("address difference between password_buffer and dummy_variable: %lld\n", (long long)password_buffer - (long long)&dummy_variable);

    // neorv32_uart0_printf("address difference between password_buffer and is_authorized: %i\n", (long)password_buffer - (long)&is_authorized);
    // neorv32_uart0_printf("address difference between password_buffer and dummy_variable: %i\n", (long)password_buffer - (long)&dummy_variable);

    // neorv32_uart0_printf("is_autorized address: %p\n", (void*)&is_authorized);
    // neorv32_uart0_printf("password_buffer address: %p\n", (void*)password_buffer);
    // neorv32_uart0_printf("dummy_variable address: %p\n", (void*)&dummy_variable);

    print_variable_address((uint32_t)&is_authorized, "is_authorized");
    print_variable_address((uint32_t)password_buffer, "password_buffer");
    print_variable_address((uint32_t)&dummy_variable, "dummy_variable");

    // flush any previously received characters in both uarts
    // soft-reset of CPU doesn't seem to handle this well
    while (neorv32_uart_char_received(NEORV32_UART0)) {
        char c = neorv32_uart_getc(NEORV32_UART0);
    }
    while (neorv32_uart_char_received(NEORV32_UART1)) {
        char c = neorv32_uart_getc(NEORV32_UART1);
    }


    // the only purpose of this line is to check if the 
    // program modification attack works well (without the need
    // to scan a QR code in the lab)
    unsigned long long barcode_num = barcode_str_to_num("123456789");

    neorv32_uart1_puts("reset\n"); // '\n' needed because of gets not adding '\n' at the end

LOGIN:
    while(!is_authorized) {
        while (!neorv32_uart_char_received(NEORV32_UART1)) {
        // while (!neorv32_uart1_available()) {
            wait_ms(500);
        }
        // let all characters arrive
        wait_ms(300);
        // gets/scanf are vulnerable to buffer overflow, if we supply more than 4 characters, 
        // we can overwrite the is_authorized variable without knowing the correct password
        neorv32_uart0_puts("password buffer before gets: '");
        neorv32_uart0_puts(password_buffer);
        neorv32_uart0_puts("'\n");
        neorv32_uart_gets(NEORV32_UART1, password_buffer);
        neorv32_uart0_puts("Received password: ");
        neorv32_uart0_puts(password_buffer);
        neorv32_uart0_puts("\n");
        if(!strcmp(password_buffer, CORRECT_PASSWORD)) {
            is_authorized = 1;
        } else {
            neorv32_uart1_puts("Incorrect password!\n"); // '\n' needed because of gets not adding '\n' at the end
        }
    }
    neorv32_uart1_puts("Access granted!\n"); // '\n' needed because of gets not adding '\n' at the end

    while (true) {
        while (!neorv32_uart_char_received(NEORV32_UART1)) {
        // while (!neorv32_uart1_available()) {
            wait_ms(500);
        }
        // let all characters arrive
        wait_ms(300);
        neorv32_uart_gets(NEORV32_UART1, cmd);
        if (!strcmp(cmd, "logout")) {
            neorv32_uart1_puts("Logged out\n"); // '\n' needed because of gets not adding '\n' at the end
            is_authorized = 0;
            goto LOGIN;
        }
        unsigned long long barcode = barcode_str_to_num(barcode_str);
        // check validity of barcode just for the sake of processing it in some way
        bool is_valid = is_barcode_valid(barcode);
        if (is_barcode_known(barcode_str)) {
            neorv32_uart1_puts("Known ID: doors opened\n"); // '\n' needed because of gets not adding '\n' at the end
        } else {
            neorv32_uart1_puts("Unknown ID: doors closed\n"); // '\n' needed because of gets not adding '\n' at the end
        }
    }
}


bool is_barcode_known(char *barcode) {
    // Sending "bc:12908409184\n" to pynq will make it lookup sqlite database 
    // (that is automatically initialized with default values on boot)
    // This is vulnerable because the database check it made in the 
    // following way:
    //
    //    def is_barcode_in_db(self, barcode):
    //        # secure:
    //        # self.c.execute("SELECT * FROM allowed_barcode_IDs WHERE barcode_ID = ?", (barcode,))
    // 
    //        # vulnerable to sql injection:
    //        self.c.execute(f"SELECT * FROM allowed_barcode_IDs WHERE barcode_ID = {barcode}")
    // 
    //        return self.c.fetchone() is not None  
    // 
    // We can send any value followed by "OR 1=1" (e.g. "bc:123 OR 1=1\n") and it will return true (1)
    // regardless if the barcode is in the database or not.
    neorv32_uart0_printf("bc:%s\n", barcode);
    int is_in_db = false;
    wait_ms(500);
    // get response from SQL database on PYNQ

    char response[256];
    neorv32_uart_gets(NEORV32_UART0, response);
    sscanf(response, "bc:%d", &is_in_db);
    // neorv32_uart_gets(NEORV32_UART0, response);
    // neorv32_uart_sscanf(response, "bc:%d", &is_in_db);
    return is_in_db > 0;
}
                                                    
bool is_barcode_valid(unsigned long long barcode) {
    return is_ean13_barcode(barcode) || is_upca_barcode(barcode);
}

bool is_ean13_barcode(unsigned long long barcode) {
    char barcodeStr[14];
    snprintf(barcodeStr, sizeof(barcodeStr), "%lld", barcode);
    if (strlen(barcodeStr) != 13) return false;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
        int digit = barcodeStr[i] - '0';
        if (i % 2 == 0)
            sum += digit;
        else
            sum += 3 * digit;
    }
    int checkDigit = (10 - (sum % 10)) % 10;
    return (checkDigit == barcodeStr[12] - '0');
}

bool is_upca_barcode(unsigned long long barcode) {
    char barcodeStr[13];
    snprintf(barcodeStr, sizeof(barcodeStr), "%lld", barcode);
    if (strlen(barcodeStr) != 12) return false;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
        int digit = barcodeStr[i] - '0';
        if (i % 2 == 0) 
            sum += 3 * digit;
        else
            sum += digit;
    }
    int checkDigit = (10 - (sum % 10)) % 10;
    return (checkDigit == barcodeStr[11] - '0');
}

unsigned long long barcode_str_to_num(char *barcode_str) {
    unsigned long long barcode = 0;
    sscanf(barcode_str, "%llu", &barcode);

    return barcode;
}
