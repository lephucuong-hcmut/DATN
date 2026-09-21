`timescale 1ns / 1ps

module concat_code
#( 

    parameter parameter_set = "hqc192",
                                                   
    parameter N1_BYTES =    (parameter_set == "hqc128")? 46:
				            (parameter_set == "hqc192")? 56:
				            (parameter_set == "hqc256")? 90:
				                                         46,
	
	parameter K_BYTES = (parameter_set == "hqc128")? 16:
				        (parameter_set == "hqc192")? 24:
			            (parameter_set == "hqc256")? 32: 
                                                     16,
	
	parameter N1 = 8*N1_BYTES,
	parameter K = 8*K_BYTES,
	
	parameter LOG_N1_BYTES = `CLOG2(N1_BYTES)
													
)
(
    input clk,
    input rst,
    input start,
    input [K-1:0] msg_in,
	
    input cdw_out_en,
    input [LOG_N1_BYTES-1:0] cdw_out_addr,
	output [127:0] cdw_out,
    output done
	
    );
    
	
	wire [N1-1:0] rs_cdw_out;
	wire done_rs;
	
    reed_solomon_encode 
  #(.parameter_set(parameter_set))
  REED_SOLOMON_CODE
  ( .clk(clk),
    .rst(rst),
    .start(start),
    .msg_in(msg_in),
    .cdw_out(rs_cdw_out),
    .done(done_rs)
    );
	
	
  reed_muller_encode 
  #(.parameter_set(parameter_set))
  REED_MULLER_ENCODE
  ( .clk(clk),
    .rst(rst),
    .start(done_rs),
    .rs_cdw_in(rs_cdw_out),
    .cdw_out_addr(cdw_out_addr),
    .cdw_out_en(cdw_out_en),
    .cdw_out(cdw_out),
    .done(done)
    );


    
    
endmodule