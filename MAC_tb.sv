module MAC_tb;

logic clk;
logic rst;

logic valid_in;
logic clear_acc;

logic signed [7:0] a;
logic signed [7:0] b;

logic valid_out;
logic signed [7:0] acc_out;

MAC uut(
    .clk(clk),
    .rst(rst),
    .valid_in(valid_in),
    .clear_acc(clear_acc),
    .in_a(a),
    .in_b(b),
    .valid_out(valid_out),
    .acc_out(acc_out)
);


always #5 clk = ~clk;

task test_mac(input signed [7:0] aa,
              input signed [7:0] bb);
begin
    @(posedge clk);
    a = aa;
    b = bb;
    valid_in = 1;

    @(posedge clk);
    valid_in = 0;
end
endtask


initial begin

clk = 0;
rst = 1;
valid_in = 0;
clear_acc = 0;

#20
rst = 0;


// reset accumulator
@(posedge clk);
clear_acc = 1;

@(posedge clk);
clear_acc = 0;


//3 MAC operations

test_mac(27,15);   // 1.6875*0.9375
test_mac(25,21);   // 1.5625*1.3125
test_mac(14,18);   // 0.875*1.125


#100

$display("Accumulated fixed result = %d",acc_out);
$display("Accumulated real result  = %f",acc_out/16.0);

$finish;

end

endmodule