// Copyright by Adam Kinsman and Henry Ko and Nicola Nicolici
// Developed for the Digital Systems Design course (COE3DQ4)
// Department of Electrical and Computer Engineering
// McMaster University
// Ontario, Canada

`timescale 1ns/100ps

`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"

// This module generates the address for reading the SRAM
// in order to display the image on the screen
module m1 (
   // I/O
	input logic 				CLOCK_50,
	input logic 				resetn,	
	input logic		[15:0]   SRAM_read_data,
	input logic 				m1_start,

	output logic   [17:0]   SRAM_address,
   output logic   [15:0]   SRAM_write_data,
   output logic            SRAM_we_n,
	output logic				m1_done	
);


m1_state_type m1_state;

parameter U_OFFSET = 18'd38400,
          V_OFFSET = 18'd57600,
          RGB_OFFSET = 18'd146944;

integer i;			 
			 
// Registers
//logic [15:0] read_data;
logic read_flag;
logic lead_out;

//data counters
logic [17:0] data_counter_Y;
logic [17:0] data_counter_U;
logic [17:0] data_counter_V;
logic [17:0] data_counter_RGB;
logic [9:0] pixel_count;

//U registers
logic [31:0] U_prime_odd;
logic [7:0] U_prime_even;
logic [7:0] U_buf;
logic [7:0] U_reg [5:0];
logic signed [31:0] AccU;

//V registers
logic [31:0] V_prime_odd;
logic [7:0] V_prime_even;
logic [7:0] V_buf;
logic [7:0] V_reg [5:0];
logic signed [31:0] AccV;

//Y registers 
logic [7:0] Y_even;
logic [7:0] Y_odd;
logic signed [31:0] Yconst_even, Yconst_odd;

//RGB registers
logic signed [31:0] red, green, blue;
logic [7:0] red_out, green_out, blue_out;
logic [7:0] red_odd, red_even;
logic [7:0] green_odd, green_even;
logic [7:0] blue_odd, blue_even;

assign red_out = red[31]? 8'd0: |red[30:24]? 8'd255: red[23:16];
assign green_out = green[31]? 8'd0: |green[30:24]? 8'd255: green[23:16];
assign blue_out = blue[31]? 8'd0: |blue[30:24]? 8'd255: blue[23:16];

//Multiplier 1
logic [3:0] select1;
logic signed [31:0] multi_op1, multi_op2, multi_result1;
logic signed [63:0] multi_result_long;

always_comb begin
	case(select1)
		4'd0: begin 
			multi_op1 = 32'd159; 
			multi_op2 = U_reg[3] + U_reg[2]; // 159 calc for U
		end
		4'd1: begin 
			multi_op1 = -32'd52; 
			multi_op2 = U_reg[4] + U_reg[1]; // -52 calc for U
		end
		4'd2: begin 
			multi_op1 = 32'd21; 
			multi_op2 = U_reg[5] + U_reg[0]; // 21 calc for U
		end
		4'd3: begin 
			multi_op1 = -32'd25624; 
			multi_op2 = U_prime_even - 'd128; // calc 1 for green for even
		end 
		4'd4: begin 
			multi_op1 = 32'd104595; 
			multi_op2 = V_prime_even - 'd128; // calc for red even 
		end 
		4'd5: begin 
			multi_op1 = -32'd53281; 
			multi_op2 = V_prime_odd - 'd128; // calc 2 for green for odd
		end
		4'd6: begin 
			multi_op1 = 32'd159; 
			multi_op2 = V_reg[3] + V_reg[2]; // 159 calc for V
		end
		4'd7: begin // hopefully correct
			multi_op1 = 32'd76284; 
			multi_op2 = Y_even - 'd16; // y even constant calc 
		end
		4'd8: begin
			multi_op1 = 32'd76284; 
			multi_op2 = Y_odd - 'd16;  // y odd constant calc 
		end
		4'd9: begin 
			multi_op1 = 32'd104595; 
			multi_op2 = V_prime_odd - 'd128; // calc for red odd 
		end
	endcase
end
assign multi_result_long = multi_op1*multi_op2;
assign multi_result1 = multi_result_long[31:0];

//Multiplier 2
logic [3:0] select2;
logic signed [31:0] multi_op1_2, multi_op2_2, multi_result2;
logic signed [63:0] multi_result_long2;
always_comb begin
	case(select2)
		4'd0: begin 
			multi_op1_2 = 32'd76284; 
			multi_op2_2 = Y_even - 'd16; // y even constant calc 
		end
		4'd1: begin 
			multi_op1_2 = -32'd53281;
			multi_op2_2 = V_prime_even - 'd128; // calc 2 for green for even
		end
		4'd2: begin
			multi_op1_2 = 32'd76284; 
			multi_op2_2 = Y_odd - 'd16;  // y odd constant calc 
		end
		4'd3: begin 
			multi_op1_2 = 32'd132251; 
			multi_op2_2 = U_prime_odd - 'd128; // blue calc for odd 
		end 
		4'd4: begin 
			multi_op1_2 = -32'd25624; 
			multi_op2_2 = U_prime_odd - 'd128; // calc 1 for green for odd
		end 
		4'd5: begin 
			multi_op1_2 = -32'd52; 
			multi_op2_2 = V_reg[4] + V_reg[1]; // -52 calc for V
		end
		4'd6: begin 
			multi_op1_2 = -32'd52; 
			multi_op2_2 = U_reg[4] + U_reg[1]; // -52 calc for U
		end
		4'd7: begin 
			multi_op1_2 = 32'd104595; 
			multi_op2_2 = V_prime_even - 'd128; // calc for red even 
		end 
	endcase
end
assign multi_result_long2 = multi_op1_2*multi_op2_2;
assign multi_result2 = multi_result_long2[31:0];

//Multiplier 3
logic [3:0] select3;
logic signed [31:0] multi_op1_3, multi_op2_3, multi_result3;
logic signed [63:0] multi_result_long3;
always_comb begin
	case(select3)
		4'd0: begin 
			multi_op1_3 = 32'd132251; 
			multi_op2_3 = U_prime_even - 'd128; // blue calc for even 
		end
		4'd1: begin 
			multi_op1_3 = 32'd159; 
			multi_op2_3 = V_reg[3] + V_reg[2]; // 159 calc for V
		end
		4'd2: begin 
			multi_op1_3 = -32'd52; 
			multi_op2_3 = V_reg[4] + V_reg[1]; // -52 calc for V
		end
		4'd3: begin 
			multi_op1_3 = -32'd53281; 
			multi_op2_3 = V_prime_odd - 'd128; // calc 2 for green for odd
		end
		4'd4: begin 
			multi_op1_3 = 32'd104595; 
			multi_op2_3 = V_prime_odd - 'd128; // calc for red odd 
		end
		4'd5: begin 
			multi_op1_3 = 32'd21; 
			multi_op2_3 = V_reg[5] + V_reg[0]; // 21 calc for V
		end
		4'd6: begin 
			multi_op1_3 = 32'd159; 
			multi_op2_3 = U_reg[3] + U_reg[2]; // 159 calc for U
		end
		4'd7: begin 
			multi_op1_3 = -32'd25624; 
			multi_op2_3 = U_prime_even - 'd128; // calc 1 for green for even
		end 
	endcase
end
assign multi_result_long3 = multi_op1_3*multi_op2_3;
assign multi_result3 = multi_result_long3[31:0];

always_ff @ (posedge CLOCK_50 or negedge resetn) begin
	if (~resetn) begin
		m1_state <= S_M1_IDLE;
		data_counter_Y <= 18'd0;;
		data_counter_U <= 18'd0;
		data_counter_V <= 18'd0;;
		data_counter_RGB <= 18'd0;
		AccU <= 32'd0;
		AccV <= 32'd0;
		SRAM_we_n <= 1'b1;		//active LO -> read on reset
		read_flag <= 1'd0;
		pixel_count <= 10'd0;
		lead_out <= 1'd0;
		m1_done <= 1'b0;
	end else begin
		case (m1_state)
		S_M1_IDLE: begin 
			if (m1_start == 1'b1 && m1_done == 1'b0) m1_state <= S_LEAD_IN_0;
		end 	
		S_LEAD_IN_0: begin
		  SRAM_we_n <= 1'b1; // disable
		  read_flag <= 1'd0;
		  lead_out <= 1'd0;
		  
			SRAM_address <= data_counter_U + U_OFFSET;  // read 0 + U
			data_counter_U <= data_counter_U + 18'd1;
			
			m1_state <= S_LEAD_IN_1;
		end
		S_LEAD_IN_1: begin
			SRAM_address <= data_counter_U + U_OFFSET; // read 1 + U
			data_counter_U <= data_counter_U + 18'd1;
			
			m1_state <= S_LEAD_IN_2;
		end
		S_LEAD_IN_2: begin
			SRAM_address <= data_counter_Y;  // read 1 + Y
			data_counter_Y <= data_counter_Y + 18'd1;
			AccU <= 32'd128;
			
			m1_state <= S_LEAD_IN_3;
		end
		S_LEAD_IN_3: begin
			SRAM_address <= data_counter_V + V_OFFSET; // read 0 +V 
			data_counter_V <= data_counter_V + 18'd1;
			
			//read_data <= SRAM_read_data;  // get U0, U1 values
			U_prime_even <= SRAM_read_data[15:8];
			pixel_count <= 10'd0;
			U_reg[0] <= SRAM_read_data[15:8];  //U[(j-5)/2)] U0
			U_reg[1] <= SRAM_read_data[15:8];  //U[(j-3)/2)] U0
			U_reg[2] <= SRAM_read_data[15:8];  //U[(j-1)/2)] U0
			U_reg[3] <= SRAM_read_data[7:0]; //U[(j+1)/2)] U1
			
			//AccU <= AccU + -32'd52*(U_reg[3]) + $unsigned(U_reg[2]));
			
			select1 <= 4'd0;
			
			m1_state <= S_LEAD_IN_4;
		end
		S_LEAD_IN_4: begin
			SRAM_address <= data_counter_V + V_OFFSET; // read 1 + V 
			data_counter_V <= data_counter_V + 18'd1;
			
			//read_data <= SRAM_read_data;  // get U0, U1 values
			U_reg[5] <= SRAM_read_data[7:0];  //U[(j+5)/2)] U3
			U_reg[4] <= SRAM_read_data[15:8];  //U[(j+3)/2)] U2
			
			AccU <= AccU + multi_result1;	//select = 4'd9 add 159 product to U 
			
			select1 <= 4'd1;
			
			m1_state <= S_LEAD_IN_5;
		end
		S_LEAD_IN_5: begin
			SRAM_address <= data_counter_U + U_OFFSET; // read 2 + U 
			data_counter_U <= data_counter_U + 18'd1;
			
			//read_data <= SRAM_read_data;  // get Y0, Y1 values
			Y_even <= SRAM_read_data[15:8];  //Y0
			Y_odd <= SRAM_read_data[7:0];  //Y1

			AccU <= AccU + multi_result1; // -52 product to AccU 
			
			select2 <= 4'd0;
			select1 <= 4'd2;
			select3 <= 4'd0;

			m1_state <= S_LEAD_IN_6;
		end
		S_LEAD_IN_6: begin
			SRAM_address <= data_counter_Y;  // read 1 + Y
			data_counter_Y <= data_counter_Y + 18'd1;
		
			//read_data <= SRAM_read_data;		//get V0, V1 values
			//U_prime <= {{8{AccU[31]}},AccU>>8};
			
			V_prime_even <= SRAM_read_data[15:8];
			V_reg[0] <= SRAM_read_data[15:8];  //V[(j-5)/2)] V0
			V_reg[1] <= SRAM_read_data[15:8];  //V[(j-3)/2)] V0
			V_reg[2] <= SRAM_read_data[15:8];  //V[(j-1)/2)] V0
			V_reg[3] <= SRAM_read_data[7:0]; //V[(j+1)/2)] V1
			
			Yconst_even <= multi_result2; // calculate Y constant for RGB even
			
			AccU <= AccU + multi_result1;  // add 21 product to accU
			
			blue <= multi_result3; // calculate blue 
			
			AccV <= 32'd128; // start accV 
			
			select3 <= 4'd1;
			select1 <= 4'd3; // multi result green calc 1
			select2 <= 4'd1; // multi recsult green calc 2
			
			m1_state <= S_LEAD_IN_7;
		end 
		S_LEAD_IN_7: begin
			//read_data <= SRAM_read_data;		//get V2, V3 values
			U_prime_odd <= AccU>>>8;
			
			V_reg[5] <= SRAM_read_data[7:0];  //V[(j+5)/2)] V3
			V_reg[4] <= SRAM_read_data[15:8];  //V[(j+3)/2)] V2
			
			blue <= blue + Yconst_even;
			
			AccV <= AccV + multi_result3; // add 159 product to AccV

			select1 <= 4'd4;
			select2 <= 4'd2;
			select3 <= 4'd2;

			green <= Yconst_even + multi_result1 + multi_result2; // green calc
			
			m1_state <= S_LEAD_IN_8;
		end 
		S_LEAD_IN_8: begin

			//read_data <= SRAM_read_data;		//get U4, U5 values

			U_prime_even <= U_reg[3]; // U'2 = U1
			pixel_count <= pixel_count + 10'd2;
			
			U_reg[5] <= SRAM_read_data[15:8]; // put U4 into U[(j+5)/2] or register 5
			for (i=0; i<5; i=i+1)
				U_reg[i] <= U_reg[i+1]; // shift U values 
			
			U_buf <= SRAM_read_data[7:0]; // U5 value goes to U buf
				
			AccU <= 32'd128;	
			
			red = Yconst_even + multi_result1;  // calc red
			
			
			blue_even <= blue[31]? 8'd0: |blue[30:24]? 8'd255: blue[23:16];
			green_even <= green[31]? 8'd0: |green[30:24]? 8'd255: green[23:16]; 
			Yconst_odd = multi_result2; // calc y constant for even
						select1 <= 4'd0;
			select3 <= 4'd5;

			AccV <= AccV + multi_result3; // add product 52
			
			m1_state <= S_LEAD_IN_9;
		end 
		S_LEAD_IN_9: begin
			SRAM_address <= data_counter_V + V_OFFSET; // read 2 + V 
			data_counter_V <= data_counter_V + 18'd1;
			
			//read_data <= SRAM_read_data;		//get Y2, Y3 values
			red_even <= red[31]? 8'd0: |red[30:24]? 8'd255: red[23:16]; 
			Y_even <= SRAM_read_data[15:8]; // Y2
			Y_odd <= SRAM_read_data[7:0]; // Y3
			
			AccU <= AccU + multi_result1;	//select = 4'd0 add 159 product to U 
			
			AccV <= AccV + multi_result3; // add 21 product to AccV 
						select2 <= 4'd3;

			m1_state <= S_LEAD_IN_10;
		end 
		S_LEAD_IN_10: begin
			V_prime_odd <= AccV >>> 8;
		
			blue <= Yconst_odd + multi_result2;
						select2 <= 4'd4;
			select3 <= 4'd3;
			select1 <= 4'd9;
			m1_state <= S_LEAD_IN_11;
		end 
		S_LEAD_IN_11: begin
			blue_odd <= blue[31]? 8'd0: |blue[30:24]? 8'd255: blue[23:16]; // blue odd calc 

			green <= Yconst_odd + multi_result2 + multi_result3;
			
			select1 <= 4'd1;
			select2 <= 4'd0;
			
			red <= Yconst_odd + multi_result1; // red calc 

			m1_state <= S_LEAD_IN_12;
		end 
		S_LEAD_IN_12: begin
			SRAM_address <= data_counter_RGB + RGB_OFFSET;  // 0 + RGB
			data_counter_RGB <= data_counter_RGB + 18'd1;
			
			green_odd <= green[31]? 8'd0: |green[30:24]? 8'd255: green[23:16];
			red_odd <= red[31]? 8'd0: |red[30:24]? 8'd255: red[23:16];

			SRAM_we_n <= 1'd0;
			SRAM_write_data <= {red_even, green_even} ;	//write R0, G0
			
			//read_data <= SRAM_read_data;		//get V4, V5 values
			
			AccU <= AccU + multi_result1; // -52 product to AccU 
			
			Yconst_even <=  multi_result2; // y const even 
			
			for (i=0; i<5; i=i+1)
				V_reg[i] <= V_reg[i+1]; // shift V values 
			V_reg[5] <= SRAM_read_data[15:8]; // put V4 into V[(j+5)/2] or register 5
			
			V_buf <= SRAM_read_data[7:0]; // V5 value goes to V buf
			
			AccV <= 32'd128;
			
			V_prime_even <= V_reg[3]; // V'2 = V1
						select1 <= 4'd3;
			select2 <= 4'd1;		
			select3 <= 4'd1;

			m1_state <= S_LEAD_IN_13;
		end 
		S_LEAD_IN_13: begin
			SRAM_address <= data_counter_RGB + RGB_OFFSET; // 1 + RGB
			data_counter_RGB <= data_counter_RGB + 18'd1;
			
			SRAM_write_data <= {blue_even, red_odd} ;	//write B0, R1
			

			green <= Yconst_even + multi_result1 + multi_result2;	//calc for green even (G2)
			select1 <= 4'd2;

			AccV <= AccV + multi_result3;	//calc 159 product for V
			
			m1_state <= S_LEAD_IN_14;
		end 
		S_LEAD_IN_14: begin 
			green_even <= green[31]? 8'd0: |green[30:24]? 8'd255: green[23:16];

			AccU <= AccU + multi_result1;  // 21 product for U
			
			SRAM_we_n <= 1'b1; // disable write
			
			select1 <= 4'd4;
			select3 <= 4'd0;
			select2 <= 4'd5;

			m1_state <= S_LEAD_IN_15;
		end 
		S_LEAD_IN_15: begin
			SRAM_address <= data_counter_RGB + RGB_OFFSET;	// 2 + RGB
			data_counter_RGB <= data_counter_RGB + 18'd1;
			
			
			SRAM_we_n <= 1'b0; // disable write
			SRAM_write_data <= {green_odd, blue_odd} ;	//write G1, B1
			
			red <= Yconst_even + multi_result1;		//calc red even (R2)
			
			blue <= Yconst_even + multi_result3;  //calc blue even (B2
			
			U_prime_odd <= AccU>>>8;		//set U'
			
			AccV <= AccV + multi_result2;		//acc 52 product for V
						select2 <= 4'd2;
			select3 <= 4'd5;

			m1_state <= S_LEAD_IN_16;
		end 
		S_LEAD_IN_16: begin
			SRAM_we_n <= 1'd1;		//disable write/ enable read
			
			red_even <= red[31]? 8'd0: |red[30:24]? 8'd255: red[23:16];
			blue_even <= blue[31]? 8'd0: |blue[30:24]? 8'd255: blue[23:16];

			Yconst_odd <= multi_result2;		//calc Y const odd
		
			AccV <= AccV + multi_result3;		//acc 21 product for V
			
			AccU <= 32'd128;		
			
			select2 <= 4'd3;

			m1_state <= S_LEAD_IN_17;
		end 
		S_LEAD_IN_17: begin
			blue <= Yconst_odd + multi_result2; // blue odd calc 
			
			V_prime_odd <= AccV >>> 8;
			
			select3 <= 4'd4;
			select1 <= 4'd5;
			select2 <= 4'd4;
			
			m1_state <= S_LEAD_IN_18;
		end 
		S_LEAD_IN_18: begin
      blue_odd <= blue[31]? 8'd0: |blue[30:24]? 8'd255: blue[23:16];

			red <= Yconst_odd + multi_result3;			

			green <= Yconst_odd + multi_result1 + multi_result2;

			m1_state <= S_LEAD_IN_19;
		end 
		S_LEAD_IN_19: begin
		  SRAM_address <= data_counter_Y;  // 2 + Y
			data_counter_Y <= data_counter_Y + 18'd1;
			
			red_odd <= red[31]? 8'd0: |red[30:24]? 8'd255: red[23:16];
			
			m1_state <= S_COMMON_0;
		end 
		S_COMMON_0: begin
			
			SRAM_address <= data_counter_RGB + RGB_OFFSET; // RGB address 
			data_counter_RGB <= data_counter_RGB + 18'd1; // RGB address + 1
			
			SRAM_we_n <= 1'b0; // write 
			
			SRAM_write_data <= {red_even, green_even}; //write red even and green even 
			
			U_prime_even <= U_reg[3]; // U' even = U[j/2]
			pixel_count <= pixel_count + 10'd2;			
			
			if (read_flag == 1'b0) begin 
				U_reg[5] <= U_buf; // put new value into U[(j+5)/2] or register 5
			end else begin 
				//read_data <= SRAM_read_data; // read from sram data 
				U_reg[5] <= SRAM_read_data[15:8]; // put new value into U[(j+5)/2] or register 5
				U_buf <= SRAM_read_data[7:0]; // new value into buffer 
			end 
	
			for (i=0; i<5; i=i+1)
				U_reg[i] <= U_reg[i+1]; // shift U values 
			
			green_odd <= green[31]? 8'd0: |green[30:24]? 8'd255: green[23:16];
			V_prime_even <= V_reg[3]; // V' even = V[j/2]
			select1 <= 4'd2;
			select2 <= 4'd6;
			select3 <= 4'd6;
			m1_state <= S_COMMON_1;
		end 
		S_COMMON_1: begin
			SRAM_address <= data_counter_RGB + RGB_OFFSET; // RGB address 
			data_counter_RGB <= data_counter_RGB + 18'd1; // RGB address + 1
			
			SRAM_write_data <= {blue_even, red_odd}; //write blue even and red odd
						
	    if(pixel_count == 10'd310) begin // set condition to go to lead out case 
				lead_out <= 1'b1;
			end
			
			AccU <= 32'd128 + multi_result1 + multi_result2 + multi_result3; // 21 + 52 + 159
			
			if (read_flag == 1'b0) begin 
				V_reg[5] <= V_buf; // put new value into V[(j+5)/2] or register 5
			end else begin 
				//read_data <= SRAM_read_data; // read from sram data 
				V_reg[5] <= SRAM_read_data[15:8]; // put new value into V[(j+5)/2] or register 5
				V_buf <= SRAM_read_data[7:0]; // new value into buffer 
			end 
			
			for (i=0; i<5; i=i+1)
				V_reg[i] <= V_reg[i+1]; // shift V values 
				
			select1 <= 4'd6; // V 159
			select2 <= 4'd5;
			select3 <= 4'd5;
			m1_state <= S_COMMON_2;
		end 
		S_COMMON_2: begin
			SRAM_address <= data_counter_RGB + RGB_OFFSET; // RGB address 
			data_counter_RGB <= data_counter_RGB + 18'd1; // RGB address + 1
			
			SRAM_write_data <= {green_odd, blue_odd}; //write green odd and blue odd
					
			//read_data <= SRAM_read_data;
			
			Y_even <= SRAM_read_data[15:8]; // get Y even and odd values 
			Y_odd <= SRAM_read_data[7:0];
			
			U_prime_odd <= AccU >>> 8;		//set U'
			
			select1 <= 4'd7; // y
      
			select2 <= 4'd7;
			select3 <= 4'd0;
			AccV <= 32'd128 + multi_result1 + multi_result2 + multi_result3; // 159 + 52 + 21
		   //AccV <= AccV +  // Acc 159 product 
		   
			m1_state <= S_COMMON_3;
		end 
		S_COMMON_3: begin
			SRAM_we_n <= 1'b1;

			select3 <= 4'd7; // calc 2 for green 
			select2 <= 4'd1; // calc 1 for green 
			select1 <= 4'd8;
      
      Yconst_even = multi_result1;
      
			red <= multi_result2;
			
			blue <= multi_result3;

			m1_state <= S_COMMON_4;
		end 
		S_COMMON_4: begin
			if (read_flag == 1'b0 && lead_out != 1'b1) begin 
				SRAM_address <= data_counter_U + U_OFFSET; // read U 
				data_counter_U <= data_counter_U + 18'd1; // + 1
			end 
			
			red <= red + Yconst_even;
			blue <= blue + Yconst_even;
			
			select2 <= 4'd3; // blue odd
			select3 <= 4'd4; // red odd 
			
			green <= Yconst_even + multi_result2 + multi_result3;
			
			Yconst_odd <= multi_result1; // y constant odd 

			V_prime_odd <= AccV>>>8;		//set V'
			
			m1_state <= S_COMMON_5;
		end 
		S_COMMON_5: begin
			if (read_flag == 1'b0 && lead_out != 1'b1) begin 
				SRAM_address <= data_counter_V + V_OFFSET; // read V 
				data_counter_V <= data_counter_V + 18'd1; // + 1
			end 
			
			red_even <= red[31]? 8'd0: |red[30:24]? 8'd255: red[23:16]; // red even calc 
			blue_even <= blue[31]? 8'd0: |blue[30:24]? 8'd255: blue[23:16]; // blue even calc 

			green_even <= green[31]? 8'd0: |green[30:24]? 8'd255: green[23:16]; // green calc

			select2 <= 4'd4; // green calc 1
			select1 <= 4'd5; // green calc 2 
			
			red <= Yconst_odd + multi_result3;
			
			blue <= Yconst_odd + multi_result2;
			
			m1_state <= S_COMMON_6;
		end 
		S_COMMON_6: begin
			SRAM_address <= data_counter_Y; // read Y 
			data_counter_Y <= data_counter_Y + 18'd1; // + 1
			
			red_odd <= red[31]? 8'd0: |red[30:24]? 8'd255: red[23:16]; // red odd calc 
			blue_odd <= blue[31]? 8'd0: |blue[30:24]? 8'd255: blue[23:16]; // blue odd calc 

			green <= Yconst_odd + multi_result1 + multi_result2;
			
			read_flag <= ~read_flag;
			
			if (lead_out) begin 
				m1_state <= S_LEAD_OUT_0;
			end else begin 
				m1_state <= S_COMMON_0;
			end	
		end 
		S_LEAD_OUT_0: begin
			SRAM_address <= data_counter_RGB + RGB_OFFSET; // RGB address 
			data_counter_RGB <= data_counter_RGB + 18'd1; // RGB address + 1
			
			SRAM_we_n <= 1'b0; // write 
			
			SRAM_write_data <= {red_even, green_even}; //write red even and green even 
			
			U_prime_even <= U_reg[3]; // U' even = U[j/2]
			pixel_count <= pixel_count + 10'd2;
			
			U_reg[5] <= U_buf; // put new value into U[(j+5)/2] or register 5
			for (i=0; i<5 ; i=i+1)
				U_reg[i] <= U_reg[i+1]; // shift U values 
		
			green_odd <= green[31]? 8'd0: |green[30:24]? 8'd255: green[23:16];
			V_prime_even <= V_reg[3]; // V' even = V[j/2]
			select1 <= 4'd2;
			select2 <= 4'd6;
			select3 <= 4'd6;
			m1_state <= S_LEAD_OUT_1;			
		end 
		S_LEAD_OUT_1: begin
			SRAM_address <= data_counter_RGB + RGB_OFFSET; // RGB address 
			data_counter_RGB <= data_counter_RGB + 18'd1; // RGB address + 1
			
			SRAM_write_data <= {blue_even, red_odd}; //write blue even and red odd
						

			AccU <= 32'd128 + multi_result1 + multi_result2 + multi_result3; // 21 + 52 + 159
			
			V_reg[5] <= V_buf; // put new value into V[(j+5)/2] or register 5
			for (i=0; i<5; i=i+1)
				V_reg[i] <= V_reg[i+1]; // shift V values 
			
			select1 <= 4'd6;
			select2 <= 4'd5;
			select3 <= 4'd5;
			m1_state <= S_LEAD_OUT_2;
		end 
		S_LEAD_OUT_2: begin
			SRAM_address <= data_counter_RGB + RGB_OFFSET; // RGB address 
			data_counter_RGB <= data_counter_RGB + 18'd1; // RGB address + 1
			
			SRAM_write_data <= {green_odd, blue_odd}; //write green odd and blue odd
					
			//read_data <= SRAM_read_data;
			
			Y_even <= SRAM_read_data[15:8]; // get Y even and odd values 
			Y_odd <= SRAM_read_data[7:0];
			
			U_prime_odd <= AccU >>> 8;		//set U'
			
			select1 <= 4'd7; // y even
			select2 <= 4'd7;
			select3 <= 4'd0;

			AccV <= 32'd128 + multi_result1 + multi_result2 + multi_result3; // 52 + 21
		  // AccV <= AccV + ; // Acc 159 product 
		  
			m1_state <= S_LEAD_OUT_3;
		end 
		S_LEAD_OUT_3: begin
			SRAM_we_n <= 1'b1;

      Yconst_even = multi_result1;
      
			select3 <= 4'd7; // calc 2 for green 
			select2 <= 4'd1; // calc 1 for green 
						select1 <= 4'd8;

			red <= multi_result2;
			
			blue <= multi_result3;

			m1_state <= S_LEAD_OUT_4;
		end 
		S_LEAD_OUT_4: begin
			select2 <= 4'd3; // blue odd
			select3 <= 4'd4; // red odd 

			green <= Yconst_even + multi_result2 + multi_result3;
			
			Yconst_odd <= multi_result1; // y constant odd 

			V_prime_odd <= AccV>>>8;		//set V'
			
			red <= Yconst_even + red;
			blue <= Yconst_even + blue;
			
			m1_state <= S_LEAD_OUT_5;
		end 
		S_LEAD_OUT_5: begin
			select2 <= 4'd4; // green calc 1
			select1 <= 4'd5; // green calc 2 
						
			red_even <= red[31]? 8'd0: |red[30:24]? 8'd255: red[23:16]; // red even calc 
			blue_even <= blue[31]? 8'd0: |blue[30:24]? 8'd255: blue[23:16]; // blue even calc 
			green_even <= green[31]? 8'd0: |green[30:24]? 8'd255: green[23:16]; // green calc

			red <= Yconst_odd + multi_result3;
			
			blue <= Yconst_odd + multi_result2;
			
			m1_state <= S_LEAD_OUT_6;
		end 
		S_LEAD_OUT_6: begin 
		  if (pixel_count != 10'd318) begin 
			 SRAM_address <= data_counter_Y; // read Y 
			 data_counter_Y <= data_counter_Y + 18'd1; // + 1
			end
			
			red_odd <= red[31]? 8'd0: |red[30:24]? 8'd255: red[23:16]; // red odd calc 
			blue_odd <= blue[31]? 8'd0: |blue[30:24]? 8'd255: blue[23:16]; // blue odd calc 

			
			green <= Yconst_odd + multi_result1 + multi_result2;
			
			if (pixel_count == 10'd318) begin 
				m1_state <= S_LEAD_OUT_7;
			end 
			else begin
				m1_state <= S_LEAD_OUT_0;
			end
		end 
		S_LEAD_OUT_7: begin
			SRAM_we_n <= 1'b0;
		
			green_odd <= green[31]? 8'd0: |green[30:24]? 8'd255: green[23:16];

			SRAM_address <= data_counter_RGB + RGB_OFFSET; // RGB address 
			data_counter_RGB <= data_counter_RGB + 18'd1; // RGB address + 1
			
			SRAM_write_data <= {red_even, green_even}; //write green odd and blue odd
					
			m1_state <= S_LEAD_OUT_8;
		end 
		S_LEAD_OUT_8: begin
			SRAM_address <= data_counter_RGB + RGB_OFFSET; // RGB address 
			data_counter_RGB <= data_counter_RGB + 18'd1; // RGB address + 1
			
			SRAM_write_data <= {blue_even, red_odd}; //write green odd and blue odd
					
			m1_state <= S_LEAD_OUT_9;
		end 
		S_LEAD_OUT_9: begin
			SRAM_address <= data_counter_RGB + RGB_OFFSET; // RGB address 
			data_counter_RGB <= data_counter_RGB + 18'd1; // RGB address + 1
			
			SRAM_write_data <= {green_odd, blue_odd}; //write green odd and blue odd
					
			if ((data_counter_RGB + RGB_OFFSET) == 18'd262143) begin 
				m1_done <= 1'b1;
				m1_state <= S_M1_IDLE;			
			end else begin
				m1_state <= S_LEAD_IN_0;
			end
		end 
		default: m1_state <= S_M1_IDLE;
		endcase	
	end

end 



endmodule
