module spi_drv_tb ();
  
  parameter integer               CLK_DIVIDE  = 4;   // Clock divider to indicate frequency of SCLK
  parameter integer               SPI_MAXLEN  = 16;  // Maximum SPI transfer length
  parameter integer 			  CLK_DELAY = 2;     // To decide the clock frequency

  logic sresetn = 1'b0;  
  logic SCLK;
  logic clk = 1'b0;
  logic r_MOSI;
  logic r_start_cmd = 1'b0;
  logic r_spi_drv_rdy;
  logic r_SS_N;
  logic [SPI_MAXLEN-1:0] r_tx_data = 0;
  logic [$clog2(SPI_MAXLEN):0]   r_n_clks;
  logic [SPI_MAXLEN-1:0] r_rx_miso;

  // Clock Generator
  always #(CLK_DELAY) clk = ~clk;

  // Instantiate UUT
  spi_drv 
  #(.CLK_DIVIDE(CLK_DIVIDE),
    .SPI_MAXLEN(SPI_MAXLEN)) spi_drv_UUT
  (
   .sresetn(sresetn),     
   .clk(clk),   
   .SCLK(SCLK),   
   .tx_data(r_tx_data),            
   .rx_miso(r_rx_miso),
   .n_clks(r_n_clks),
   .start_cmd(r_start_cmd),
   .spi_drv_rdy(r_spi_drv_rdy),
   .MOSI(r_MOSI),
   .MISO(r_MOSI),  
   // sending the MOSI output to MISO. If after the transfer rx_miso[nclks-1:0] is equal to tx_data[nclks-1:0]
   // then no error in both MISO and MOSI transfer
   .SS_N(r_SS_N)
   );


  // Sends data of length N_CLK from SPI master.
  task SendData(input [SPI_MAXLEN-1:0] data, input [$clog2(SPI_MAXLEN):0] n_clk);
    @(posedge clk);
    r_tx_data <= data;
	r_n_clks <= n_clk;
    r_start_cmd   <= 1'b1;
    @(posedge clk);
    r_start_cmd <= 1'b0;
    r_tx_data <= 0;
	r_n_clks <= 0;
    @(posedge r_spi_drv_rdy); // wait till SPI transfer is completed
  endtask 

  
  initial
    begin
      $dumpfile("dump.vcd"); 
      $dumpvars;
      
      repeat(10) @(posedge clk);
      sresetn  = 1'b0;
      repeat(10) @(posedge clk);
      sresetn  = 1'b1;
      
	  // If SPI_MAXLEN = 16 and data sent to tx_data = 16'BFA3,
      // Should receive first 16 bits on rx_miso if N_CLK = 16 i.e. 16'hBFA3
	  // Should receive first 8 bits on rx_miso if N_CLK = 8 i.e. 16'h00A3
	  // Should receive first 4 bits on rx_miso if N_CLK = 4 i.e. 16'h0003
      SendData(16'hBFA3,5'b10000);
      $display("Sent out 0xbfa3, Received 0x%X", r_rx_miso); 
      SendData(16'h12BE,5'b01000);
      $display("Sent out 0x12be, Received 0x%X", r_rx_miso); 
      SendData(16'h45EF,5'b00100);
      $display("Sent out 0x45ef, Received 0x%X", r_rx_miso); 
	  SendData(16'h347F,5'b00010);
      $display("Sent out 0x347f, Received 0x%X", r_rx_miso); 
      SendData(16'h12A3,5'b00001);
      $display("Sent out 0x12a3, Received 0x%X", r_rx_miso);
      repeat(10) @(posedge clk);
      $finish();      
    end 

endmodule