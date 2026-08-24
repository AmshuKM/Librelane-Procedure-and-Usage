module counter(
input wire clk,
input wire reset,updown,
output reg [3:0]q );


always@(posedge clk)
begin
if (reset==0)
begin
if (updown==1)
q <= q +1;
else
q <= q -1;
end
else
q=0; 
end

endmodule
