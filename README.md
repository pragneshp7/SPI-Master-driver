# SPI Master driver
This module is used to implement a SPI master. The host will want to transmit a certain number of SCLK pulses. This number will be placed in the n_clks port. It will always be less than or equal to SPI_MAXLEN.

SPI bus timing
--------------
This SPI clock frequency should be the host clock frequency divided by CLK_DIVIDE. This value is guaranteed to be even and >= 4. SCLK should have a 50% duty cycle. The slave will expect to clock in data on the rising edge of SCLK; therefore this module should output new MOSI values on SCLK falling edges. Similarly, you should latch MISO input bits on the rising edges of SCLK.

Command Interface
-----------------
The data to be transmitted on MOSI will be placed on the tx_data port. The first bit of data to be transmitted will be bit tx_data[n_clks-1] and the last bit transmitted will be tx_data[0]. On completion of the SPI transaction, rx_miso should hold the data clocked in from MISO on each positive edge of SCLK. rx_miso[n_clks-1] should hold the first bit and rx_miso[0] will be the last.

When the host wants to issue a SPI transaction, the host will hold the start_cmd pin high. While start_cmd is asserted, the host guarantees that n_clks and tx_data are valid and stable. This module acknowledges receipt of the command by issuing a transition on spi_drv_rdy from 1 to 0. This module should then being performing the SPI transaction on the SPI lines. This module indicates completion of the command by transitioning spi_drv_rdy from 0 to 1. rx_miso must contain valid data when this transition happens, and the data must remain stable until the next command starts.
