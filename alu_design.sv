module alu (
  input  logic [7:0] a, b,
  input  logic [1:0] op,
  output logic [7:0] result
);
  always_comb begin
    case (op)
      2'b00: result = a + b;  // ADD
      2'b01: result = a - b;  // SUBTRACT
      2'b10: result = a & b;  // AND
      2'b11: result = a | b;  // OR
      default: result = 8'b0;
    endcase
  end
endmodule
