// SPI Master Module
//
// This module is used to implement a SPI master. The host will want to transmit a certain number
// of SCLK pulses. This number will be placed in the n_clks port. It will always be less than or
// equal to SPI_MAXLEN.
//
// SPI bus timing
// --------------
// This SPI clock frequency should be the host clock frequency divided by CLK_DIVIDE. This value is
// guaranteed to be even and >= 4. SCLK should have a 50% duty cycle. The slave will expect to clock
// in data on the rising edge of SCLK; therefore this module should output new MOSI values on SCLK
// falling edges. Similarly, you should latch MISO input bits on the rising edges of SCLK.
//
// Command Interface
// -----------------
// The data to be transmitted on MOSI will be placed on the tx_data port. The first bit of data to
// be transmitted will be bit tx_data[n_clks-1] and the last bit transmitted will be tx_data[0].
//  On completion of the SPI transaction, rx_miso should hold the data clocked in from MISO on each
// positive edge of SCLK. rx_miso[n_clks-1] should hold the first bit and rx_miso[0] will be the last.
//
//  When the host wants to issue a SPI transaction, the host will hold the start_cmd pin high. While
// start_cmd is asserted, the host guarantees that n_clks and tx_data are valid and stable. This
// module acknowledges receipt of the command by issuing a transition on spi_drv_rdy from 1 to 0.
// This module should then being performing the SPI transaction on the SPI lines. This module indicates
// completion of the command by transitioning spi_drv_rdy from 0 to 1. rx_miso must contain valid data
// when this transition happens, and the data must remain stable until the next command starts.
//

module spi_drv #(
    parameter integer               CLK_DIVIDE  = 100, // Clock divider to indicate frequency of SCLK
    parameter integer               SPI_MAXLEN  = 32   // Maximum SPI transfer length
) (
    input                           clk,
    input                           sresetn,           // active low reset, synchronous to clk
    
    // Command interface 
    input                           start_cmd,         // Start SPI transfer
    output reg                      spi_drv_rdy,       // Ready to begin a transfer
    input  [$clog2(SPI_MAXLEN):0]   n_clks,            // Number of bits (SCLK pulses) for the SPI transaction
    input  [SPI_MAXLEN-1:0]         tx_data,           // Data to be transmitted out on MOSI
    output reg [SPI_MAXLEN-1:0]     rx_miso,           // Data read in from MISO
    
    // SPI pins
    output reg                      SCLK,              // SPI clock sent to the slave
    output reg                      MOSI,              // Master out slave in pin (data output to the slave)
    input                           MISO,              // Master in slave out pin (data input from the slave)
    output reg                      SS_N               // Slave select, will be 0 during a SPI transaction
);
  
  reg [$clog2(SPI_MAXLEN):0]   n_clk_r;                // to store the data on n_clks when start_cmd is asserted
  reg [$clog2(SPI_MAXLEN):0]   n_clk_count;            // to keep track of number of SCLK pulses
  reg [SPI_MAXLEN-1:0]         tx_data_r;              // to store the data on tx_data when start_cmd is asserted
  reg [$clog2(CLK_DIVIDE):0]   SCLK_count_r;		   // counter for generating SCLK
  
  localparam CLK_DIVIDE_r = $unsigned(CLK_DIVIDE)/2;   // no. of clk cycles between one transition of SCLK
  
// Generating the SCLK: An adder with an array of flip flops is used to implement a counter that increases by 1 on every
// rising edge of clk. When the counter (SCLK_count_r) is equal to CLK_DIVIDE_r - 1 (CLK_DIVIDE_r = CLK_DIVIDE/2)
// the SCLK value is inverted

always@(posedge clk)
begin
	if (~sresetn) begin
		SCLK_count_r <= 0;
	end
	
	else if (~spi_drv_rdy) begin
		if (SCLK_count_r == CLK_DIVIDE_r - 1) begin
			SCLK_count_r <= 0;
		end
		else begin
			SCLK_count_r <= SCLK_count_r + 1;
		end
	end
	
	else begin
		SCLK_count_r <= 0;
	end
end

always@(posedge clk)
begin

	if (~sresetn) begin
		SCLK <= 1'b0;
		n_clk_count <= 1'b0;
	end
	
	else if (~spi_drv_rdy) begin
		if (SCLK_count_r == CLK_DIVIDE_r - 1) begin
			SCLK <= ~SCLK;
			if (SCLK) begin
				n_clk_count <= n_clk_count + 1; // incrementing n_clk_count on every falling SCLK edge
			end
			else begin
				n_clk_count <= n_clk_count;
			end
		end 
		else begin
			SCLK <= SCLK;
			n_clk_count <= n_clk_count;
		end
	end
	
	else begin 
		SCLK <= 1'b0;
		n_clk_count <= 1'b0;
	end
	
end

always@(posedge clk)
begin

	if (~sresetn) begin
		spi_drv_rdy <= 1'b1;
		SS_N <= 1'b1;
	end
	else if (start_cmd) begin
		spi_drv_rdy <= 1'b0; // initiating SPI transfer after start_cmd assertion
		SS_N <= 1'b0;
	end
	else if (n_clk_count == n_clk_r) begin
		spi_drv_rdy <= 1'b1; // SPI transfer completed after transfer of n_clks SCLK pulses
		SS_N <= 1'b1;
	end
	else begin
		spi_drv_rdy <= spi_drv_rdy;
		SS_N <= SS_N;
	end
end

// storing the tx_data input to tx_data_r and n_clks input to n_clk_r after start_cmd assertion
always@(posedge clk)
begin

	if (~sresetn) begin
		tx_data_r <= 0;
		n_clk_r <= 0;
		
	end
	else begin
		if (start_cmd) begin
			n_clk_r <= n_clks;
			tx_data_r <= tx_data;
			
		end
		else begin
			n_clk_r <= n_clk_r;
			tx_data_r <= tx_data_r;
		end
	end
end

// During the transfer n_clk_count goes from the value of 0 to n_clks - 1. n_clk_r holds the n_clks value throughout 
// the transfer. Thus, [n_clk_r-n_clk_count-1] goes from n_clks - 1 to 0 during the transfer. 
// Hence, MOSI holds the tx_data_r[n_clks - 1] data (first bit to be transmitted) during the start of transfer and 
// then decrements the [n_clk_r-n_clk_count-1] value every SCLK falling edge (since n_clk_count decrements every 
// SCLK falling edge. Hence, tx_data[n_clks - 1] holds the first bit and tx_data[0] holds the last bit

always@(posedge clk)
begin
	if (~sresetn) begin
		MOSI <= 1'b0;
	end
	else if (~spi_drv_rdy) begin
      MOSI <= tx_data_r[n_clk_r-n_clk_count-1];
	end
	else begin
		MOSI <= 1'b0;
	end
end

// rx_miso latches onto the MISO value on every rising SCLK edge. As explained above, during the transfer n_clk_count
// goes from the value of 0 to n_clks - 1. Thus, [n_clk_r-n_clk_count-1] goes from n_clks - 1 to 0 during the transfer.
// Hence, the rx_miso[n_clks - 1] holds the first bit and rx_miso[0] holds the last.

always@(posedge clk)
begin
	if (~sresetn) begin
		rx_miso <= 0;
	end
	else begin
		if (start_cmd) begin
			rx_miso <= 0; // keep data stable until next command starts
		end
		else if (~spi_drv_rdy) begin
			if (SCLK_count_r == CLK_DIVIDE_r - 1) begin
				if (~SCLK) begin // latch the data during when SCLK transitions from 0 to 1
					rx_miso[n_clk_r-n_clk_count-1] <= MISO;
				end
				else begin
					rx_miso <= rx_miso;
				end
			end 
			else begin
				rx_miso <= rx_miso;
			end
		end
		else begin
			rx_miso <= rx_miso;  // so that data remains stable until next command starts
		end
	end
end

endmodule