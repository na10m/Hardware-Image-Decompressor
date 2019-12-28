module zigzag (input logic clock, resetn, output logic[6:0] zigzag);
 always_comb begin
    if (zigzag == 6'd0) zigzag <= {3'd0, 3'd1};
    if (zigzag == {3'd0, 3'd1}) zigzag <= {3'd0, 3'd1};
    if (zigzag == {3'd0, 3'd1}) zigzag <= {3'd1, 3'd0};
    if (zigzag == {3'd1, 3'd0}) zigzag <= {3'd2, 3'd0};
    if (zigzag == {3'd2, 3'd0}) zigzag <= {3'd1, 3'd1};  //-
    if (zigzag == {3'd1, 3'd1}) zigzag <= {3'd0, 3'd2};
    if (zigzag == {3'd0, 3'd2}) zigzag <= {3'd0, 3'd3};
    if (zigzag == {3'd0, 3'd3}) zigzag <= {3'd1, 3'd2};
    if (zigzag == {3'd1, 3'd2}) zigzag <= {3'd2, 3'd1};
    if (zigzag == {3'd2, 3'd1}) zigzag <= {3'd3, 3'd0};
    if (zigzag == {3'd3, 3'd0}) zigzag <= {3'd4, 3'd0};
    if (zigzag == {3'd4, 3'd0}) zigzag <= {3'd3, 3'd1};  //
    if (zigzag == {3'd3, 3'd1}) zigzag <= {3'd2, 3'd2};
    if (zigzag == {3'd2, 3'd2}) zigzag <= {3'd1, 3'd3};
    if (zigzag == {3'd1, 3'd3}) zigzag <= {3'd0, 3'd4};
    if (zigzag == {3'd0, 3'd4}) zigzag <= {3'd0, 3'd5};
    if (zigzag == {3'd0, 3'd5}) zigzag <= {3'd1, 3'd4};
    if (zigzag == {3'd1, 3'd4}) zigzag <= {3'd2, 3'd3};
    if (zigzag == {3'd2, 3'd3}) zigzag <= {3'd3, 3'd2};
    if (zigzag == {3'd3, 3'd2}) zigzag <= {3'd4, 3'd1};
    if (zigzag == {3'd4, 3'd1}) zigzag <= {3'd5, 3'd0};
    if (zigzag == {3'd5, 3'd0}) zigzag <= {3'd6, 3'd0};
    if (zigzag == {3'd6, 3'd0}) zigzag <= {3'd5, 3'd1};
    if (zigzag == {3'd5, 3'd1}) zigzag <= {3'd4, 3'd2};
    if (zigzag == {3'd4, 3'd2}) zigzag <= {3'd3, 3'd3};
    if (zigzag == {3'd3, 3'd3}) zigzag <= {3'd2, 3'd4};
    if (zigzag == {3'd2, 3'd4}) zigzag <= {3'd1, 3'd5};
    if (zigzag == {3'd1, 3'd5}) zigzag <= {3'd0, 3'd6};
    if (zigzag == {3'd0, 3'd6}) zigzag <= {3'd0, 3'd7};
    if (zigzag == {3'd0, 3'd7}) zigzag <= {3'd1, 3'd6}; // 
    if (zigzag == {3'd1, 3'd6}) zigzag <= {3'd2, 3'd5};
    if (zigzag == {3'd2, 3'd5}) zigzag <= {3'd3, 3'd4};
    if (zigzag == {3'd3, 3'd4}) zigzag <= {3'd4, 3'd3};
    if (zigzag == {3'd4, 3'd3}) zigzag <= {3'd5, 3'd2};
    if (zigzag == {3'd5, 3'd2}) zigzag <= {3'd6, 3'd1};
    if (zigzag == {3'd6, 3'd1}) zigzag <= {3'd7, 3'd0};
    if (zigzag == {3'd7, 3'd0}) zigzag <= {3'd1, 3'd6};
    if (zigzag == {3'd0, 3'd7}) zigzag <= {3'd1, 3'd6};
    if (zigzag == {3'd0, 3'd7}) zigzag <= {3'd7, 3'd1};
    if (zigzag == {3'd7, 3'd1}) zigzag <= {3'd6, 3'd2};
    if (zigzag == {3'd6, 3'd2}) zigzag <= {3'd5, 3'd3};
    if (zigzag == {3'd5, 3'd3}) zigzag <= {3'd4, 3'd4};
    if (zigzag == {3'd4, 3'd4}) zigzag <= {3'd3, 3'd5};
    if (zigzag == {3'd3, 3'd5}) zigzag <= {3'd2, 3'd6};
    if (zigzag == {3'd2, 3'd6}) zigzag <= {3'd1, 3'd7};
    if (zigzag == {3'd1, 3'd7}) zigzag <= {3'd2, 3'd7};
    if (zigzag == {3'd2, 3'd7}) zigzag <= {3'd3, 3'd6};//
    if (zigzag == {3'd3, 3'd6}) zigzag <= {3'd4, 3'd5};
    if (zigzag == {3'd4, 3'd5}) zigzag <= {3'd5, 3'd4};
    if (zigzag == {3'd5, 3'd4}) zigzag <= {3'd6, 3'd3};
    if (zigzag == {3'd6, 3'd3}) zigzag <= {3'd7, 3'd2};
    if (zigzag == {3'd7, 3'd2}) zigzag <= {3'd7, 3'd3};
    if (zigzag == {3'd7, 3'd3}) zigzag <= {3'd6, 3'd4};
    if (zigzag == {3'd6, 3'd4}) zigzag <= {3'd5, 3'd5};
    if (zigzag == {3'd5, 3'd5}) zigzag <= {3'd4, 3'd6}; //
    if (zigzag == {3'd4, 3'd6}) zigzag <= {3'd3, 3'd7};
    if (zigzag == {3'd3, 3'd7}) zigzag <= {3'd4, 3'd7};
    if (zigzag == {3'd4, 3'd7}) zigzag <= {3'd5, 3'd6};
    if (zigzag == {3'd5, 3'd6}) zigzag <= {3'd6, 3'd5};
    if (zigzag == {3'd6, 3'd5}) zigzag <= {3'd7, 3'd4};
    if (zigzag == {3'd7, 3'd4}) zigzag <= {3'd7, 3'd5}; //
    if (zigzag == {3'd7, 3'd5}) zigzag <= {3'd6, 3'd6};
    if (zigzag == {3'd6, 3'd6}) zigzag <= {3'd5, 3'd7};
    if (zigzag == {3'd5, 3'd7}) zigzag <= {3'd6, 3'd7};
    if (zigzag == {3'd6, 3'd7}) zigzag <= {3'd7, 3'd6}; //
    if (zigzag == {3'd7, 3'd6}) zigzag <= {3'd7, 3'd7};
end

endmodule 