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
module m2 (
   // I/O
	input logic 				CLOCK_50,
	input logic 				resetn,	
	input logic		[15:0]   SRAM_read_data,
	input logic 				m2_start,

	output logic   [17:0]   SRAM_address,
   output logic   [15:0]   SRAM_write_data,
   output logic            SRAM_we_n,
	output logic				m2_done	
);

m2_state_type m2_state;

// dual port stuff
logic [6:0] address_a [1:0], address_b [1:0];
logic [31:0] write_data_a [1:0], write_data_b [1:0];
logic write_enable_a [1:0];
logic write_enable_b [1:0];
logic [31:0] read_data_a [1:0];
logic [31:0] read_data_b [1:0];

parameter U_OFFSET = 18'd38400,
          V_OFFSET = 18'd57600,
          SP_OFFSET = 18'd76800,
			 S_OFFSET = 7'd32,
			 T_OFFSET = 7'd64;

logic fetch_en;
logic [17:0] SRAM_offset;

//outside block
logic [7:0] row_address;
logic [8:0] coloumn_address;
logic [4:0] row_block;
logic [5:0] coloumn_block;

//inside block
logic [5:0] sample_index;
logic [2:0] row_index;
logic [2:0] coloumn_index;

// T calc
logic [8:0] Tcalc_counter;
logic signed [31:0] AccT [1:0];
logic [31:0] Sprime;
logic [31:0] C;
logic [31:0] T_buf;
logic [6:0] DP_Sprime_Position;
logic [6:0] DP_C_Position;
logic [6:0] DP_T_Position;
logic LastWriteT;

// S Calc
logic [8:0] Scalc_counter;
logic signed [31:0] AccS [1:0];
logic [31:0] C_t;
logic [31:0] T;
logic [7:0] S0;
logic [7:0] S1;
logic [7:0] S_buf;
logic [6:0] DP_S_Position;
logic LastWriteS;
logic WriteS;

logic write_en;
logic [17:0] data_counter_S;
logic [11:0] block_count;
logic [5:0] coloumn_block_limit;
logic [17:0] offset;
logic [5:0]	SRAM_block_count;
logic [2:0] pixel_count;
logic write_flag;
logic [10:0] write_count;

// Instantiate RAM0
dual_port_RAM0 dual_port_RAM_inst0 (
	.address_a ( address_a[0] ),
	.address_b ( address_b[0] ),
	.clock ( CLOCK_50 ),
	.data_a ( write_data_a[0] ),
	.data_b ( write_data_b[0] ),
	.wren_a ( write_enable_a[0] ),
	.wren_b ( write_enable_b[0] ),
	.q_a ( read_data_a[0] ),
	.q_b ( read_data_b[0] )
	);

// Instantiate RAM1
dual_port_RAM1 dual_port_RAM_inst1 (
	.address_a ( address_a[1] ),
	.address_b ( address_b[1] ),
	.clock ( CLOCK_50 ),
	.data_a ( write_data_a[1] ),
	.data_b ( write_data_b[1] ),
	.wren_a ( write_enable_a[1] ),
	.wren_b ( write_enable_b[1] ),
	.q_a ( read_data_a[1] ),
	.q_b ( read_data_b[1] )
	);
	
//Multiplier 1
logic [3:0] select1;
logic signed [31:0] multi_op1, multi_op2, multi_result_1;
logic signed [63:0] multi_result_long;
always_comb begin
	case(select1)
		4'd0: begin 
			multi_op1 = $signed(Sprime[15:0]) ; // S * first C
			multi_op2 = $signed(C[31:16]) ;
		end
		4'd1: begin 
			multi_op1 = $signed(C_t[31:16]) ; // Ct * first T
			multi_op2 = $signed(T) ;
		end
	endcase
end
assign multi_result_long = multi_op1*multi_op2;
assign multi_result_1 = multi_result_long[31:0];

//Multiplier 2
logic [3:0] select2;
logic signed [31:0] multi_op1_2, multi_op2_2, multi_result_2;
logic signed [63:0] multi_result_long2;
always_comb begin
	case(select2)
		4'd0: begin 
			multi_op1_2 = $signed(Sprime[15:0]) ; // S * second C
			multi_op2_2 = $signed(C[15:0]);
		end
		4'd1: begin 
			multi_op1_2 = $signed(C_t[15:0]) ; // Ct * second T
			multi_op2_2 = $signed(T) ;
		end
	endcase
end
assign multi_result_long2 = multi_op1_2*multi_op2_2;
assign multi_result_2 = multi_result_long2[31:0];

//FS and WS
always_ff @ (posedge CLOCK_50 or negedge resetn) begin
	if (~resetn) begin
		row_block <= 7'd0;
		coloumn_block <= 6'd0;
		sample_index <= 6'd0;
		data_counter_S <= 18'd0;
		offset <= 18'd0;
		coloumn_block_limit <= 6'd40;
		SRAM_write_data <= 16'd0;
		SRAM_block_count <= 5'd0;
		pixel_count <= 2'd0;
		write_count <= 11'd0;
		SRAM_offset <= 18'd76800;
	end else begin
		if (fetch_en) begin
			sample_index <= sample_index + 6'd1;			
			
			if (block_count == 12'd1199) begin
				coloumn_block_limit <= 6'd20;
			end
			
			//coloumn block addressing
			if (sample_index == 6'd63 && coloumn_block != (coloumn_block_limit - 6'd1)) begin
				coloumn_block <= coloumn_block + 6'd1;
			end
			else if (sample_index == 6'd63 && coloumn_block == (coloumn_block_limit - 6'd1)) begin
				coloumn_block <= 6'd0;
			end
			
			//row block addressing
			if (sample_index == 6'd63 && coloumn_block == (coloumn_block_limit - 6'd1)) begin
				row_block <= row_block + 5'd1;
			end
			
			if (block_count == 12'd1198 && sample_index == 6'd63) begin
				row_block <= 5'd0;
				coloumn_block <= 6'd0;
				SRAM_offset <= 18'd153600;
			end if (block_count == 12'd1798 && sample_index == 6'd63) begin
				row_block <= 5'd0;
				coloumn_block <= 6'd0;
				SRAM_offset <= 18'd192000;
			end 
			
//			else if (row_block == 5'd30) begin
//				row_block <= 5'd0;
//			end
			
			if (block_count < 12'd1199) SRAM_address <= 18'd76800 + {2'd0, row_address, 8'd0} + {4'd0, row_address, 6'd0} + {9'd0, coloumn_address};
			else SRAM_address <= SRAM_offset + {3'd0, row_address, 7'd0} + {5'd0, row_address, 5'd0} + {9'd0, coloumn_address}; // {1'd0, row_address, 7'd0} + {3'd0, row_address, 5'd0} + {9'd0, coloumn_address};//{1'd0, row_address[8:4], 1'd0, row_address[3:0], 7'd0} + {3'd0, row_address[8:4], 1'd0, row_address[3:0], 5'd0} + {9'd0, coloumn_address};
		end
		else if (write_en) begin
			SRAM_address <= data_counter_S; //+ offset;
						
			if (pixel_count == 3'd3) begin
				if (block_count < 12'd1200) begin 		//Y region
					data_counter_S <= data_counter_S + 18'd157;
				end else begin		//U, V region
					data_counter_S <= data_counter_S + 18'd77;
				end
				pixel_count <= 3'd0;
			end else begin
				pixel_count <= pixel_count + 3'd1;
				data_counter_S <= data_counter_S + 18'd1;
			end
			
			if (SRAM_block_count == 6'd31 ) begin
				if (block_count < 12'd1200 && write_count != 11'd1279) begin		//Y region
					data_counter_S <= data_counter_S - 11'd1119; 
				end else if (write_count != 10'd639) begin		//U,V region
					data_counter_S <= data_counter_S - 10'd559; 
				end
				SRAM_block_count <= 6'd0;
			end else begin
				SRAM_block_count <= SRAM_block_count + 6'd1;
			end
			
			if (block_count < 12'd1200 && write_count == 11'd1279) begin 
				data_counter_S <= data_counter_S + 11'd1;
				write_count <= 8'd0;
			end else if (block_count >= 12'd1200 && write_count == 11'd639) begin
				data_counter_S <= data_counter_S + 11'd1;
				write_count <= 8'd0;
			end	
			else begin 
				write_count <= write_count + 8'd1;
			end
			
//			if (block_count == 12'd1200) begin
//				offset <= U_OFFSET;
//			end
//			else if (block_count == 12'd1800) begin
//				offset <= V_OFFSET;
//			end
			
			SRAM_write_data <= read_data_b[1][15:0];
		end
		SRAM_we_n = ~write_en;
	end
end	
//assign SRAM_we_n = ~write_en;
assign coloumn_address = {coloumn_block, coloumn_index};
assign row_address = {row_block, row_index};
assign row_index = sample_index[5:3];			
assign coloumn_index = sample_index[2:0]; 
	
	
always_ff @ (posedge CLOCK_50 or negedge resetn) begin
	if (~resetn) begin
		m2_state <= S_M2_IDLE;
		address_a[0] <= 7'd0;
		address_b[0] <= 7'd0;
		address_a[1] <= 7'd0;
		address_b[1] <= 7'd0;
		m2_done <= 1'b0;
		fetch_en <= 1'b0;
		write_enable_a [0] <= 1'b0;
		write_enable_b [0] <= 1'b0;
		write_enable_a[1] <= 1'b0;
		write_enable_b[1] <= 1'b0;
		DP_C_Position <= 7'b0;
		DP_Sprime_Position <= 7'b0;
		DP_T_Position <= 7'b0;
		DP_S_Position <= 7'b0;
		Tcalc_counter <= 9'd0;
		Scalc_counter <= 9'd0;
		LastWriteT <= 1'b0; 
		LastWriteS <= 1'b0; 
		block_count <= 12'd0;
		write_en <= 1'b0;
		Sprime <= 32'd0;
		C <= 32'd0;
		T_buf <= 32'd0;
		WriteS <= 1'b0;
		write_flag <= 1'b0;
	end else begin
		case (m2_state)
		S_M2_IDLE: begin
			if (m2_start == 1'b1 && m2_done == 1'b0)begin
				fetch_en <= 1'b1;
				address_b[0] <= 7'd0;
				write_enable_b [0] <= 1'b0;
				write_en <= 1'b0;
				m2_state <= S_FETCH_DUMMY;
			end
		end
		S_FETCH_DUMMY: begin 
			if (sample_index == 6'd2) m2_state <=  S_FETCH_0; // dummy states to set SRAM addresses to read
		end 
		S_FETCH_0: begin
			write_enable_b [0] <= 1'b1; // enable writing to dual port 0
			write_data_b[0] <= SRAM_read_data; // read SRAM data into Dual port
			address_b[0] <= DP_Sprime_Position; // dual port address
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			
			m2_state <= S_FETCH_1;
		end
		S_FETCH_1: begin
			write_data_b[0] <= SRAM_read_data;
			address_b[0] <= DP_Sprime_Position; // dual port address
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			
			m2_state <= S_FETCH_2;
		end
		S_FETCH_2: begin
			write_data_b[0] <= SRAM_read_data;
			address_b[0] <= DP_Sprime_Position; // dual port address
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			
			m2_state <= S_FETCH_3;
		end
		S_FETCH_3: begin
			write_data_b[0] <= SRAM_read_data;
			address_b[0] <= DP_Sprime_Position; // dual port address
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			
			m2_state <= S_FETCH_4;
		end
		S_FETCH_4: begin
			if (sample_index == 6'd63) begin // this signifies the last address has been read
				fetch_en <= 1'b0;			 // will turn off fetch enable, stops fetching SRAM addresses
			end
			
			write_data_b[0] <= SRAM_read_data; // read SRAM data into Dual port
			address_b[0] <= DP_Sprime_Position; // dual port address
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			
			m2_state <= S_FETCH_5;
		end
		S_FETCH_5: begin
			write_data_b[0] <= SRAM_read_data; // read SRAM data into Dual port
			address_b[0] <= DP_Sprime_Position; // dual port address
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			
			m2_state <= S_FETCH_6;
		end
		S_FETCH_6: begin
			write_data_b[0] <= SRAM_read_data; // read SRAM data into Dual port
			address_b[0] <= DP_Sprime_Position; // dual port address
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			
			m2_state <= S_FETCH_7;
		end
		S_FETCH_7: begin			
			address_b[0] <= DP_Sprime_Position; // dual port address
			
			if (fetch_en == 1'b0) begin // this means this is state read the last value from the block
				m2_state <= S_CALC_T_DUMMY_0; // will go to the next MEGA state
				DP_Sprime_Position <= 7'd0;
				DP_C_Position <= 7'd0;
				DP_S_Position <= 7'd0;
			end 
			else begin
				write_data_b[0] <= SRAM_read_data; // read SRAM data into Dual port
				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
				m2_state <= S_FETCH_0; // does more writing to dual port
			end
		end
		S_CALC_T_DUMMY_0: begin 
			write_enable_b [0] <= 1'b0; // disable write to dual port 0
			write_enable_b[1] <= 1'b0; // disable write  
			
			// READ 0
		
			address_a[0] <= DP_Sprime_Position; // set first S prime address
			address_a[1] <= DP_C_Position; // set first C address
			
			
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;  
			DP_C_Position <= DP_C_Position + 7'd1;
			
			Tcalc_counter <= Tcalc_counter + 9'd1;
			
			m2_state <= S_CALC_T_DUMMY_1;
		end 
		S_CALC_T_DUMMY_1: begin		
		
			//READ 1
			
			address_a[0] <= DP_Sprime_Position; // set 2nd S prime address
			address_a[1] <= DP_C_Position; // set 2nd C address
			
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			DP_C_Position <= DP_C_Position + 7'd1;
			
			Tcalc_counter <= Tcalc_counter + 9'd2;
			
			if (write_flag) begin 
				address_b[1] <= S_OFFSET + DP_S_Position;
				DP_S_Position <= DP_S_Position + 7'd1;
			end
				
			m2_state <= S_CALC_T_DUMMY_2;
		end
		S_CALC_T_DUMMY_2: begin
			 
			// RECEIVE 0
			
			Sprime <= read_data_a[0];
			C <= read_data_a[1];
			
			// READ 2
			
			address_a[0] <= DP_Sprime_Position; // set S prime address
			address_a[1] <= DP_C_Position; // set C address
			
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			DP_C_Position <= DP_C_Position + 7'd1;
			
			Tcalc_counter <= Tcalc_counter + 9'd2;
			
			DP_T_Position <= 7'd0; // address for first T write
			
			// MULTIPLIERS FOR CALCULATING T
			
			select1 <= 4'd0;
			select2 <= 4'd0;
			
			//WRITE STUFF
			
			if (write_flag) begin 
				write_en <= 1'b1;
				address_b[1] <= S_OFFSET + DP_S_Position;
				DP_S_Position <= DP_S_Position + 7'd1;
			end
		
			m2_state <= S_CALC_T_DUMMY_3;
		end
		S_CALC_T_DUMMY_3: begin 
		
			// RECEIVE DATA 1
			
			Sprime <= read_data_a[0];
			C <= read_data_a[1];
			
			// READ 3
		
			address_a[0] <= DP_Sprime_Position; // set S prime address
			address_a[1] <= DP_C_Position; // set C addresss
			
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			DP_C_Position <= DP_C_Position + 7'd1;
			
			Tcalc_counter <= Tcalc_counter + 9'd2;
			
			// USE 0 DATA 
			
			AccT[0] <= multi_result_1;  // S06 * C60 read_data_a[0]*C0
			AccT[1] <= multi_result_2;  // S06 * C61
			
			//WRITE
			if (write_en) begin 
				address_b[1] <= S_OFFSET + DP_S_Position;
				DP_S_Position <= DP_S_Position + 7'd1;
			end
		
			m2_state <= S_CALC_T_0;
		end 
		S_CALC_T_0: begin
		
			// WRITE T1
			
			if (DP_T_Position != 7'd0) begin 
				write_enable_b[0] <= 1'b1; // write  
				address_b[0] <= T_OFFSET + DP_T_Position;
				DP_T_Position <= DP_T_Position + 7'd1;
				write_data_b[0] <= T_buf;
			end 
			
			// RECEIVE DATA 2
			
			Sprime <= read_data_a[0];
			C <= read_data_a[1];
			
			// READ 4 
			
			address_a[0] <= DP_Sprime_Position; // set S prime address
			address_a[1] <= DP_C_Position; // set C address
			
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			DP_C_Position <= DP_C_Position + 7'd1;
			
			Tcalc_counter <= Tcalc_counter + 9'd2;
			
			// USE 1 DATA 
			
			AccT[0] <= AccT[0] + multi_result_1;  
			AccT[1] <= AccT[1] + multi_result_2; 
			
			// WRITE STUFF 
			
			if (write_en) begin 
				address_b[1] <= S_OFFSET + DP_S_Position;
				DP_S_Position <= DP_S_Position + 7'd1;
			end
			
			m2_state <= S_CALC_T_1;
		end
		S_CALC_T_1: begin
			// DISABLE WRITE DATA FOR WRITING T 
			
			write_enable_b [0] <= 1'b0; // disable write to dual port 1
			
			// RECEIVE DATA 3
			
			Sprime <= read_data_a[0];
			C <= read_data_a[1];
			
			// READ 5
			
			address_a[0] <= DP_Sprime_Position; // set S prime address
			address_a[1] <= DP_C_Position; // set C address
			
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			DP_C_Position <= DP_C_Position + 7'd1;
			
			Tcalc_counter <= Tcalc_counter + 9'd2;
			
			// USE 2 DATA 
			
			AccT[0] <= AccT[0] + multi_result_1;  // S01 * C10 read_data_a[0]*C0
			AccT[1] <= AccT[1] + multi_result_2;  // S01 * C11
			
			// WRITE STUFF 
			
			if (write_en) begin 
				address_b[1] <= S_OFFSET + DP_S_Position;
				DP_S_Position <= DP_S_Position + 7'd1;
			end
			
			m2_state <= S_CALC_T_2;
		end	
		S_CALC_T_2: begin
		
			// RECEIVE DATA 4
			
			Sprime <= read_data_a[0];
			C <= read_data_a[1];
		
			// READ 6
			
			address_a[0] <= DP_Sprime_Position; // set S prime address
			address_a[1] <= DP_C_Position; // set C address
			
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			DP_C_Position <= DP_C_Position + 7'd1;
			
			Tcalc_counter <= Tcalc_counter + 9'd4; // don't count in next one 
			
			// USE 3 DATA 
			
			AccT[0] <= AccT[0] + multi_result_1;  // S02 * C20 read_data_a[0]*C0
			AccT[1] <= AccT[1] + multi_result_2;  // S02 * C21
			
			// WRITE STUFF 
			
			if (write_en) begin 
				address_b[1] <= S_OFFSET + DP_S_Position;
				DP_S_Position <= DP_S_Position + 7'd1;
			end
			
			m2_state <= S_CALC_T_3;
		end		
		S_CALC_T_3: begin
			// RECEIVE DATA 5
		
			Sprime <= read_data_a[0];
			C <= read_data_a[1];
			
			// READ 7
			
			address_a[0] <= DP_Sprime_Position; // set S prime address
			address_a[1] <= DP_C_Position; // set C address
			
			// NEW ADDRESS 0
			
			// if Tcalc_counter is a multitple of 16 (15, 31, 47), all need values for the T value will be read, set back 7 to read S values again 
			// unless Tcalc_counter is a multiple of 64 (63, 127, etc...) as well, then the row of T elements has been calculated in the matrix 
			// if Tcalc_counter hits 511, then everything that will be readed to compute the entire T matrix has been read. 
			
			if (Tcalc_counter[3:0] == 4'b1111 && Tcalc_counter[5:3] != 3'b111) begin //to start S values over again for next 2 elements in T row 
				
				DP_Sprime_Position <= DP_Sprime_Position - 7'd7;
				DP_C_Position <= DP_C_Position + 7'd1;
				
			end if (Tcalc_counter[5:0] == 6'b111111) begin // last calculation in a row of T matrix
			
				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
				DP_C_Position <= 7'd0;
				
			end if (Tcalc_counter == 9'b111111111) begin 
			
				LastWriteT <= 1'b1; 
				
			end 
			
			// USE 4 DATA 
					
			AccT[0] <= AccT[0] + multi_result_1;  // S03 * C30 read_data_a[0]*C0
			AccT[1] <= AccT[1] + multi_result_2;  // S03 * C31
			
			// WRITE STUFF 
			
			if (write_en) begin 
				address_b[1] <= S_OFFSET + DP_S_Position;
				DP_S_Position <= DP_S_Position + 7'd1;
			end
			
			m2_state <= S_CALC_T_4;
		end		
		S_CALC_T_4: begin
			// RECEIVE DATA 6
			
			Sprime <= read_data_a[0];
			C <= read_data_a[1];
		
			// READ 0
			
			address_a[0] <= DP_Sprime_Position; // set S prime address
			address_a[1] <= DP_C_Position; // set C address
			
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			DP_C_Position <= DP_C_Position + 7'd1;
			
			Tcalc_counter <= Tcalc_counter + 9'd2;
			
			// USE 5 DATA 
			
			AccT[0] <= AccT[0] + multi_result_1;  // S04 * C40 read_data_a[0]*C0
			AccT[1] <= AccT[1] + multi_result_2;  // S04 * C41
			
			// WRITE STUFF 
			
			if (write_en) begin 
				address_b[1] <= S_OFFSET + DP_S_Position;
				DP_S_Position <= DP_S_Position + 7'd1;
			end
			
			
			m2_state <= S_CALC_T_5;
		end		
		S_CALC_T_5: begin
			// RECEIVE DATA 7
		
			Sprime <= read_data_a[0];
			C <= read_data_a[1];
			
			// READ 1
			
			address_a[0] <= DP_Sprime_Position; // set S prime address
			address_a[1] <= DP_C_Position; // set C address
			
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			DP_C_Position <= DP_C_Position + 7'd1;
			
			Tcalc_counter <= Tcalc_counter + 9'd2;
			
			// USE 6 DATA 
			
			AccT[0] <= AccT[0] + multi_result_1;  // S05 * C50 read_data_a[0]*C0
			AccT[1] <= AccT[1] + multi_result_2;  // S05 * C51
			
			// WRITE STUFF 
			
			if (write_en) begin 
				address_b[1] <= S_OFFSET + DP_S_Position;
				DP_S_Position <= DP_S_Position + 7'd1;
			end
			
						
			m2_state <= S_CALC_T_6;
		end		
		S_CALC_T_6: begin // logic for read for T calculation 
			// RECEIVE DATA 0
			
			Sprime <= read_data_a[0];
			C <= read_data_a[1];
			
			// READ 2 
			
			address_a[0] <= DP_Sprime_Position; // set S prime address
			address_a[1] <= DP_C_Position; // set C address
			
			DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			DP_C_Position <= DP_C_Position + 7'd1;
			
			Tcalc_counter <= Tcalc_counter + 9'd2;
			
			// USE 7 DATA 
		
			AccT[0] <= AccT[0] + multi_result_1;  // S06 * C60 read_data_a[0]*C0
			AccT[1] <= AccT[1] + multi_result_2;  // S06 * C61
			
			// WRITE STUFF 
			
			if (write_en) begin 
				address_b[1] <= S_OFFSET + DP_S_Position;
				DP_S_Position <= DP_S_Position + 7'd1;
			end
			
			if(DP_S_Position == 7'd33) begin 
				write_en <= 1'b0;
				DP_S_Position <= 7'd0;
				block_count <= block_count + 12'd1;
			end
			
			m2_state <= S_CALC_T_7;
		end		
		S_CALC_T_7: begin
			// WRITE T0 VALUE 
			
			write_enable_b[0] <= 1'b1; // write  
			address_b[0] <= T_OFFSET + DP_T_Position;
			DP_T_Position <= DP_T_Position + 7'd1;
			write_data_b[0] <= $signed(AccT[0][31:8]);
			T_buf <= $signed(AccT[1][31:8]);
			
			if (LastWriteT == 1'b1) begin 
			
				LastWriteT <= 1'b0; // reset values 
				DP_C_Position <= 7'b0;
				DP_Sprime_Position <= 7'b0;
				DP_S_Position <= 7'd0; // address for first T write
				Tcalc_counter <= 9'd0;
				write_en <= 1'b0;
				m2_state <= S_CALC_T_WRITE_0;
				
			end else begin 
				// RECEIVE DATA 1 
				
				Sprime <= read_data_a[0];
				C <= read_data_a[1];
				
				// READ 3
				
				address_a[0] <= DP_Sprime_Position; // set S prime address
				address_a[1] <= DP_C_Position; // set C address
				
				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
				DP_C_Position <= DP_C_Position + 7'd1;
				
				Tcalc_counter <= Tcalc_counter + 9'd2;
				
				// USE 0
				
				AccT[0] <= multi_result_1;  // S00 * C00 read_data_a[0]*C0
				AccT[1] <= multi_result_2;  // S00 * C01
				
				m2_state <= S_CALC_T_0;
			end 
			
			// WRITE STUFF 
			
			if (write_en) begin 
				address_b[1] <= S_OFFSET + DP_S_Position;
				DP_S_Position <= DP_S_Position + 7'd1;
			end
			
		end

		S_CALC_T_WRITE_0: begin 
			write_enable_b[0] <= 1'b1; // write  
			address_b[0] <= T_OFFSET + DP_T_Position;
			DP_T_Position <= 7'd0;
			write_data_b[0] <= T_buf;
			write_flag <= 1'b1;
			
			m2_state <= S_CALC_S_DUMMY_0;

		end 

		S_CALC_S_DUMMY_0: begin
			// DISABLE WRITE DATA FOR WRITING T 
			
			write_enable_b [0] <= 1'b0; // disable write to dual port 1
			
			if (block_count != 12'd2399) fetch_en <= 1'b1;
				
			// READ 0 
			
			address_a[1] <= DP_C_Position; // set first C trans prime address
			address_a[0] <= T_OFFSET + DP_T_Position; // set first T address
			
			DP_C_Position <= DP_C_Position + 7'd1;  
			DP_T_Position <= DP_T_Position + 7'd8;
		
			Scalc_counter <= Scalc_counter + 9'd1;
		
			m2_state <= S_CALC_S_DUMMY_1;
		end S_CALC_S_DUMMY_1: begin		
			
			// READ 1
			
			address_a[1] <= DP_C_Position; // set second  C trans prime address
			address_a[0] <= T_OFFSET + DP_T_Position; // set second T address
			
			DP_C_Position <= DP_C_Position + 7'd1;  
			DP_T_Position <= DP_T_Position + 7'd8;
			
			Scalc_counter <= Scalc_counter + 9'd2;
				
			m2_state <= S_CALC_S_DUMMY_2;
		end
		S_CALC_S_DUMMY_2: begin
			// RECEIVE DATA 0 
			
			C_t <= read_data_a[1];
			T <= read_data_a[0];
			
			// READ 2
			
			address_a[1] <= DP_C_Position; // set C trans address
			address_a[0] <= T_OFFSET + DP_T_Position; // set T address
			
			DP_C_Position <= DP_C_Position + 7'd1;  
			DP_T_Position <= DP_T_Position + 7'd8;
			
			Scalc_counter <= Scalc_counter + 9'd2;
			
			// SET MULTIPLERS FOR S CALC 
			
			select1 <= 4'd1;
			select2 <= 4'd1;
		
			m2_state <= S_CALC_S_DUMMY_3;
		end
		S_CALC_S_DUMMY_3: begin
			// RECEIVE DATA 1 
			
			C_t <= read_data_a[1];
			T <= read_data_a[0];
			
			// READ 3
			
			address_a[1] <= DP_C_Position; // set C trans address
			address_a[0] <= T_OFFSET + DP_T_Position; // set T address
			
			DP_C_Position <= DP_C_Position + 7'd1;  
			DP_T_Position <= DP_T_Position + 7'd8;
			
			Scalc_counter <= Scalc_counter + 9'd2;
			
			// USE 0 DATA 
			
			AccS[0] <= multi_result_1;  
			AccS[1] <= multi_result_2;  
			
			// DON'T WRITE S FIRST TIME 
			
			WriteS <= 1'b0;
		
			m2_state <= S_CALC_S_0;
		end 
		S_CALC_S_0: begin
			// WRITE 
				
			if (WriteS) begin 
				write_enable_b[1] <= 1'b1; // write  
				address_b[1] <= S_OFFSET + DP_S_Position + 7'd4; 
				if (DP_S_Position == 7'd3 || DP_S_Position == 7'd11 || DP_S_Position == 7'd19 || DP_S_Position == 7'd35) begin 
					DP_S_Position <= DP_S_Position + 7'd5;
				end else begin 
					DP_S_Position <= DP_S_Position + 7'd1;
				end 
				write_data_b[1] <= { S1, S_buf };
			end 
			
			if (Scalc_counter > 9'd15) WriteS <= ~WriteS;
			
			// RECEIVE DATA 2 
			
			C_t <= read_data_a[1];
			T <= read_data_a[0];
			
			// READ 4
			
			address_a[1] <= DP_C_Position; // set C trans address
			address_a[0] <= T_OFFSET + DP_T_Position; // set T address
			
			DP_C_Position <= DP_C_Position + 7'd1;  
			DP_T_Position <= DP_T_Position + 7'd8;
			
			Scalc_counter <= Scalc_counter + 9'd2;
			
			//  USE 1
		
			AccS[0] <= AccS[0] + multi_result_1;  // Ct 00 * T 00 
			AccS[1] <= AccS[1] + multi_result_2;  // Ct 00 * T 01 
			
			// FETCH STUFF 
			
			if (fetch_en == 1'b1) begin
				write_enable_b[0] <= 1'b1;
				write_data_b[0] <= SRAM_read_data;
				address_b[0] <= DP_Sprime_Position;
				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			end 
			
			if (address_b[0] == 7'd63) begin 
				write_enable_b[0] <= 1'b0;
			end 
			
			m2_state <= S_CALC_S_1;
		end
		S_CALC_S_1: begin
		
			// DISABLE WRITE 
			
			write_enable_b[1] <= 1'b0; // disable  

			// RECEIVE DATA 3
			
			C_t <= read_data_a[1];
			T <= read_data_a[0];
			
			// READ 5
			
			address_a[1] <= DP_C_Position; // set C trans address
			address_a[0] <= T_OFFSET + DP_T_Position; // set T address
			
			DP_C_Position <= DP_C_Position + 7'd1;  
			DP_T_Position <= DP_T_Position + 7'd8;
			
			Scalc_counter <= Scalc_counter + 9'd2;
			
			// USE 2
		
			AccS[0] <= AccS[0] + multi_result_1;  
			AccS[1] <= AccS[1] + multi_result_2; 

// 			FETCH STUFF 

//			if (fetch_en == 1'b1) begin
//				write_data_b[0] <= SRAM_read_data;
//				address_b[0] <= DP_Sprime_Position;
//				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
//			end

			if (sample_index == 6'd63) begin
				fetch_en <= 1'b0;
			end
			
			if (address_b[0] <= 7'd63) begin 
				write_data_b[0] <= SRAM_read_data;
				address_b[0] <= DP_Sprime_Position;
				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			end 
			
			if (address_b[0] == 7'd63) begin 
				write_enable_b[0] <= 1'b0;
			end 
			
			m2_state <= S_CALC_S_2;
		end	
		S_CALC_S_2: begin
			// RECEIVE DATA 4 
			
			C_t <= read_data_a[1];
			T <= read_data_a[0];
			
			// READ 6
			
			address_a[1] <= DP_C_Position; // set C trans address
			address_a[0] <= T_OFFSET + DP_T_Position; // set T address
			
			DP_C_Position <= DP_C_Position + 7'd1;  
			DP_T_Position <= DP_T_Position + 7'd8;
			
			Scalc_counter <= Scalc_counter + 9'd4;  // add for the next cycle as well  
			
			// USE 3

			AccS[0] <= AccS[0] + multi_result_1;  // Ct 01 * T 10 
			AccS[1] <= AccS[1] + multi_result_2;  // Ct 01 * T 11 
			
			// FETCH STUFF 
			
//			if (fetch_en == 1'b1) begin
//				write_data_b[0] <= SRAM_read_data;
//				address_b[0] <= DP_Sprime_Position;
//				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
//			end
//			
			if (sample_index == 6'd63) begin
				fetch_en <= 1'b0;
			end
			
			if (address_b[0] <= 7'd63) begin 
				write_data_b[0] <= SRAM_read_data;
				address_b[0] <= DP_Sprime_Position;
				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			end 
			
			if (address_b[0] == 7'd63) begin 
				write_enable_b[0] <= 1'b0;
			end 
			
			m2_state <= S_CALC_S_3;
		end		
		S_CALC_S_3: begin
		
			// RECEIVE DATA 5
			
			C_t <= read_data_a[1];
			T <= read_data_a[0];
			
			// READ 7 
			
			address_a[1] <= DP_C_Position; // set C trans address
			address_a[0] <= T_OFFSET + DP_T_Position; // set T address
			
			// SET ADDRESS FOR 0
			
			// if Tcalc_counter is a multitple of 16 (15, 31, 47), all needed values for the T value will be read, set back 7 to read S values again 
			// unless Tcalc_counter is a multiple of 64 (63, 127, etc...) as well, then the row of T elements has been calculated in the matrix 
			// if Tcalc_counter hits 511, then everything that will be readed to compute the entire T matrix has been read. 
			
			if (Scalc_counter[3:0] == 4'b1111 && Scalc_counter[6:3] != 4'b1111) begin //to start S values over again for next 2 elements in T row 
				
				DP_C_Position <= DP_C_Position - 7'd7; // starts T at {T02, T03}
				DP_T_Position <= DP_T_Position - 7'd55;
				
			end 

			if (Scalc_counter[6:0] == 7'b1111111) begin  
			
				DP_C_Position <= DP_C_Position + 7'd1; // starts T at {T02, T03}
				DP_T_Position <= 7'd0;
			
			end if (Scalc_counter == 9'b111111111) begin //511
			
				LastWriteS <= 1'b1; 
				
			end 
			
			// USE 4
			
			AccS[0] <= AccS[0] + multi_result_1;  // Ct 01 * T 10 
			AccS[1] <= AccS[1] + multi_result_2;  // Ct 01 * T 11 
			
			// FETCH STUFF
			
//			if (fetch_en == 1'b1) begin
//				write_data_b[0] <= SRAM_read_data;
//				address_b[0] <= DP_Sprime_Position;
//				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
//			end
			
			if (sample_index == 6'd63) begin
				fetch_en <= 1'b0;
			end
			
			if (address_b[0] <= 7'd63) begin 
				write_data_b[0] <= SRAM_read_data;
				address_b[0] <= DP_Sprime_Position;
				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			end 
			
			if (address_b[0] == 7'd63) begin 
				write_enable_b[0] <= 1'b0;
			end 
			
			m2_state <= S_CALC_S_4;
		end		
		S_CALC_S_4: begin
			// RECEIVE DATA 6 
			
			C_t <= read_data_a[1];
			T <= read_data_a[0];
			
			// READ 0
			
			address_a[1] <= DP_C_Position; // set C trans address
			address_a[0] <= T_OFFSET + DP_T_Position; // set T address
			
			DP_C_Position <= DP_C_Position + 7'd1;
			DP_T_Position <= DP_T_Position + 7'd8;
			
			Scalc_counter <= Scalc_counter + 9'd2; 
			
			// USE 5

			AccS[0] <= AccS[0] + multi_result_1;  // Ct 01 * T 10 
			AccS[1] <= AccS[1] + multi_result_2;  // Ct 01 * T 11 
			
			// FETCH STUFF 
			
			
			if (sample_index == 6'd63) begin
				fetch_en <= 1'b0;
			end
			
			if (address_b[0] <= 7'd63) begin 
				write_data_b[0] <= SRAM_read_data;
				address_b[0] <= DP_Sprime_Position;
				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			end 
			
			if (address_b[0] == 7'd63) begin 
				write_enable_b[0] <= 1'b0;
			end 
			
			m2_state <= S_CALC_S_5;
		end		
		S_CALC_S_5: begin
			// RECEIVE DATA 7 
			
			C_t <= read_data_a[1];
			T <= read_data_a[0];
			
			// READ 1
			
			address_a[1] <= DP_C_Position; // set C trans address
			address_a[0] <= T_OFFSET + DP_T_Position; // set T address
			
			DP_C_Position <= DP_C_Position + 7'd1;
			DP_T_Position <= DP_T_Position + 7'd8;
			
			Scalc_counter <= Scalc_counter + 9'd2; 
			
			// USE 6

			AccS[0] <= AccS[0] + multi_result_1;  // Ct 01 * T 10 
			AccS[1] <= AccS[1] + multi_result_2;  // Ct 01 * T 11 
			
			// FETCH STUFF 
			
			if (sample_index == 6'd63) begin
				fetch_en <= 1'b0;
			end
			
			if (address_b[0] <= 7'd63) begin 
				write_data_b[0] <= SRAM_read_data;
				address_b[0] <= DP_Sprime_Position;
				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			end 
			
			if (address_b[0] == 7'd63) begin 
				write_enable_b[0] <= 1'b0;
			end 
			
			m2_state <= S_CALC_S_6;
		end		
		S_CALC_S_6: begin 
			// RECEIVE DATA 0
			
			C_t <= read_data_a[1];
			T <= read_data_a[0];
			
			// READ 2
			
			address_a[1] <= DP_C_Position; // set C trans address
			address_a[0] <= T_OFFSET + DP_T_Position; // set T address
			
			DP_C_Position <= DP_C_Position + 7'd1;
			DP_T_Position <= DP_T_Position + 7'd8;
			
			Scalc_counter <= Scalc_counter + 9'd2; 
			
			// USE 7

			AccS[0] <= AccS[0] + multi_result_1;  // Ct 01 * T 10 
			AccS[1] <= AccS[1] + multi_result_2;  // Ct 01 * T 11 
			
			// FETCH STUFF 
			
			if (sample_index == 6'd63) begin
				fetch_en <= 1'b0;
			end
			
			if (address_b[0] <= 7'd63) begin 
				write_data_b[0] <= SRAM_read_data;
				address_b[0] <= DP_Sprime_Position;
				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			end 
			
			if (address_b[0] == 7'd63) begin 
				write_enable_b[0] <= 1'b0;
			end 
			
			m2_state <= S_CALC_S_7;
		end		
		S_CALC_S_7: begin
		
			// WRITE S
			
			if (WriteS) begin 
				write_enable_b[1] <= 1'b1; // write  
				address_b[1] <= S_OFFSET + DP_S_Position; 
				write_data_b[1] <= { S0, AccS[0][31] ? 8'd0 : |AccS[0][30:24] ? 8'd255 : AccS[0][23:16] };
				S_buf <= AccS[1][31] ? 8'd0 : |AccS[1][30:24] ? 8'd255 : AccS[1][23:16]; 
			end else begin 
				S0 <= AccS[0][31] ? 8'd0 : |AccS[0][30:24] ? 8'd255 : AccS[0][23:16];
				S1 <= AccS[1][31] ? 8'd0 : |AccS[1][30:24] ? 8'd255 : AccS[1][23:16];
			end 
			
			if (LastWriteS == 1'b1) begin 
			
				LastWriteS <= 1'b0; // reset values 
				DP_C_Position <= 7'b0;
				DP_Sprime_Position <= 7'b0;
				DP_T_Position <= 7'd0;
				Scalc_counter <= 9'd0;
				m2_state <= S_CALC_S_WRITE_0;
				
			end else begin 
				// RECEIVE DATA 1
			
				C_t <= read_data_a[1];
				T <= read_data_a[0];
				
				// READ 3
				
				address_a[1] <= DP_C_Position; // set C trans address
				address_a[0] <= T_OFFSET + DP_T_Position; // set T address
				
				DP_C_Position <= DP_C_Position + 7'd1;
				DP_T_Position <= DP_T_Position + 7'd8;
				
				Scalc_counter <= Scalc_counter + 9'd2; 
				
				// USE 0

				AccS[0] <= multi_result_1;  // Ct 01 * T 10 
				AccS[1] <= multi_result_2;  // Ct 01 * T 11 
				
				m2_state <= S_CALC_S_0;
			end 
			
			// FETCH STUFF 
			
			if (sample_index == 6'd63) begin
				fetch_en <= 1'b0;
			end
			
			if (address_b[0] <= 7'd63) begin 
				write_data_b[0] <= SRAM_read_data;
				address_b[0] <= DP_Sprime_Position;
				DP_Sprime_Position <= DP_Sprime_Position + 7'd1;
			end 
			
			if (address_b[0] == 7'd63) begin 
				write_enable_b[0] <= 1'b0;
			end 
			
		end S_CALC_S_WRITE_0: begin 
		
			write_enable_b[1] <= 1'b1; // write  
			address_b[1] <= S_OFFSET + DP_S_Position + 7'd4; 
			DP_S_Position <= 7'd0;
			write_data_b[1] <= { S1, AccS[1][31] ? 8'd0 : |AccS[1][30:24] ? 8'd255 : AccS[1][23:16] };
				
			if (block_count == 12'd2399) m2_state <= S_WRITE_S_DUMMY;
			else m2_state <= S_CALC_T_DUMMY_0;

		end 
		
		S_WRITE_S_DUMMY: begin 
			write_enable_b[1] <= 1'b0; // disable write  
			
			m2_state <= S_WRITE_S_0;
		end 
		S_WRITE_S_0: begin
		
			address_b[1] <= S_OFFSET + DP_S_Position;
			DP_S_Position <= DP_S_Position + 7'd1;
				
			m2_state <= S_WRITE_S_1;
			
		end
		S_WRITE_S_1: begin 
		
			write_en <= 1'b1;
			address_b[1] <= S_OFFSET + DP_S_Position;
			DP_S_Position <= DP_S_Position + 7'd1;
		
			m2_state <= S_WRITE_S_2;
		end
		S_WRITE_S_2: begin
			
			address_b[1] <= S_OFFSET + DP_S_Position;
			DP_S_Position <= DP_S_Position + 7'd1;
			
			m2_state <= S_WRITE_S_3;
		end 
		S_WRITE_S_3: begin 
		
			address_b[1] <= S_OFFSET + DP_S_Position;
			DP_S_Position <= DP_S_Position + 7'd1;
		
			m2_state <= S_WRITE_S_4;
		end
		S_WRITE_S_4: begin 
		
			address_b[1] <= S_OFFSET + DP_S_Position;
			DP_S_Position <= DP_S_Position + 7'd1;
		
			m2_state <= S_WRITE_S_5;
		end
		S_WRITE_S_5: begin 
		
			address_b[1] <= S_OFFSET + DP_S_Position;
			DP_S_Position <= DP_S_Position + 7'd1;
		
			m2_state <= S_WRITE_S_6;
		end
		S_WRITE_S_6: begin 
		
			address_b[1] <= S_OFFSET + DP_S_Position;
			DP_S_Position <= DP_S_Position + 7'd1;
		
			m2_state <= S_WRITE_S_7;
		end
		S_WRITE_S_7: begin 
		
			address_b[1] <= S_OFFSET + DP_S_Position;
			DP_S_Position <= DP_S_Position + 7'd1;
		
			m2_state <= S_WRITE_S_8;
		end
		S_WRITE_S_8: begin 
		
			address_b[1] <= S_OFFSET + DP_S_Position;
			DP_S_Position <= DP_S_Position + 7'd1;
		
			m2_state <= S_WRITE_S_9;
		end
		S_WRITE_S_9: begin 
		
			address_b[1] <= S_OFFSET + DP_S_Position;
			DP_S_Position <= DP_S_Position + 7'd1;
			
			if(DP_S_Position == 7'd33) begin 
				write_en <= 1'b0;
				DP_S_Position <= 7'd0;
			end

			m2_state <= S_WRITE_S_10;
		end
		S_WRITE_S_10: begin 
			
			address_b[1] <= S_OFFSET + DP_S_Position;
			DP_S_Position <= DP_S_Position + 7'd1;
			
			if (write_en == 1'b0) begin 
				m2_done <= 1'b1;
				m2_state <= S_M2_IDLE;
			end else begin
				m2_state <= S_WRITE_S_3;
			end 
			
		end

		default: m2_state <= S_M2_IDLE;
		endcase	
	end
end 


endmodule 