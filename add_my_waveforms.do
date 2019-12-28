# add waves to waveform
add wave Clock_50
add wave -divider {some label for my divider}
add wave uut/SRAM_we_n
# add wave -decimal uut/SRAM_write_data
add wave -hexadecimal uut/m2_unit/SRAM_write_data
add wave -hexadecimal uut/SRAM_read_data
add wave -unsigned uut/m2_unit/SRAM_address
add wave -unsigned uut/m2_unit/SRAM_block_count
add wave -unsigned uut/m2_unit/pixel_count
add wave -unsigned uut/m2_unit/block_count
add wave -unsigned uut/m2_unit/write_count

add wave uut/top_state
add wave uut/m2_unit/m2_state 
add wave uut/m2_unit/m2_start
add wave uut/m2_unit/m2_done


#F
add wave uut/m2_unit/fetch_en
add wave -unsigned uut/m2_unit/sample_index
add wave -unsigned uut/m2_unit/row_block
add wave -unsigned  uut/m2_unit/coloumn_block
add wave -unsigned uut/m2_unit/coloumn_block_limit 
add wave -unsigned uut/m2_unit/row_address
add wave -unsigned uut/m2_unit/coloumn_address

# Multiplier 
add wave -decimal uut/m2_unit/multi_op1
add wave -decimal uut/m2_unit/multi_op2
add wave -decimal uut/m2_unit/multi_result_1
add wave -decimal uut/m2_unit/multi_op1_2
add wave -decimal uut/m2_unit/multi_op2_2
add wave -decimal uut/m2_unit/multi_result_2

#DP
add wave uut/m2_unit/write_enable_a
add wave uut/m2_unit/write_enable_b
add wave -unsigned uut/m2_unit/address_a
add wave -unsigned uut/m2_unit/address_b
add wave -decimal uut/m2_unit/read_data_a
add wave -decimal uut/m2_unit/read_data_b
add wave -decimal uut/m2_unit/write_data_a
add wave -decimal uut/m2_unit/write_data_b

#Cs
add wave -unsigned uut/m2_unit/DP_T_Position
add wave -unsigned uut/m2_unit/DP_S_Position
add wave -unsigned uut/m2_unit/Scalc_counter
add wave -decimal uut/m2_unit/AccS
add wave -decimal uut/m2_unit/C_t
add wave -decimal uut/m2_unit/T
add wave -unsigned uut/m2_unit/S0
add wave -unsigned uut/m2_unit/S1
add wave uut/m2_unit/LastWriteS
add wave uut/m2_unit/WriteS


#W
add wave uut/m2_unit/write_en
add wave -unsigned uut/m2_unit/data_counter_S

#Ct
add wave -unsigned uut/m2_unit/DP_Sprime_Position
add wave -unsigned uut/m2_unit/DP_C_Position
add wave -unsigned uut/m2_unit/DP_T_Position
add wave -unsigned uut/m2_unit/Tcalc_counter
add wave -hexadecimal uut/m2_unit/T_buf
add wave -decimal uut/m2_unit/AccT
add wave -decimal uut/m2_unit/Sprime
add wave -decimal uut/m2_unit/C
add wave uut/m2_unit/LastWriteT


add wave uut/m2_unit/offset

#M1 stuff 
add wave uut/m1_unit/m1_state
add wave uut/m1_unit/m1_done
add wave uut/m1_start
# add wave -unsigned uut/UART_timer

add wave -decimal uut/m1_unit/pixel_count
# add wave -hexadecimal uut/m1_unit/read_data
add wave -unsigned uut/m1_unit/Y_even
add wave -unsigned uut/m1_unit/Y_odd
add wave -decimal uut/m1_unit/data_counter_RGB
add wave -decimal uut/m1_unit/data_counter_U
add wave -hexadecimal uut/m1_unit/U_prime_even
add wave -hexadecimal uut/m1_unit/U_prime_odd
add wave -decimal uut/m1_unit/AccU
add wave -hexadecimal uut/m1_unit/U_reg
add wave -hexadecimal uut/m1_unit/U_buf
add wave -decimal uut/m1_unit/data_counter_V
add wave -hexadecimal uut/m1_unit/V_prime_even
add wave -hexadecimal uut/m1_unit/V_prime_odd
add wave -decimal uut/m1_unit/AccV
add wave -hexadecimal uut/m1_unit/V_reg
add wave -hexadecimal uut/m1_unit/V_buf
add wave -decimal uut/m1_unit/red
add wave -unsigned uut/m1_unit/red_odd
add wave -unsigned uut/m1_unit/red_even
add wave -unsigned uut/m1_unit/red_out
add wave -decimal uut/m1_unit/green
add wave -unsigned uut/m1_unit/green_odd
add wave -unsigned uut/m1_unit/green_even
add wave -unsigned uut/m1_unit/green_out
add wave -decimal uut/m1_unit/blue
add wave -unsigned uut/m1_unit/blue_odd
add wave -unsigned uut/m1_unit/blue_even
add wave -unsigned uut/m1_unit/blue_out
add wave -decimal uut/m1_unit/multi_result1
add wave -decimal uut/m1_unit/multi_op1
add wave -decimal uut/m1_unit/multi_op2
add wave -decimal uut/m1_unit/multi_result2
add wave -decimal uut/m1_unit/multi_op1_2
add wave -decimal uut/m1_unit/multi_op2_2
add wave -decimal uut/m1_unit/multi_result3
add wave -decimal uut/m1_unit/multi_op1_3
add wave -decimal uut/m1_unit/multi_op2_3
add wave -decimal uut/m1_unit/Yconst_even
add wave -decimal uut/m1_unit/Yconst_odd

