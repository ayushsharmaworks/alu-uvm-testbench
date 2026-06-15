import uvm_pkg::*;
`include "uvm_macros.svh"

// Interface
interface alu_if(input logic clk);
  logic [7:0] a, b, result;
  logic [1:0] op;
endinterface

// Transaction
class alu_transaction extends uvm_sequence_item;
  `uvm_object_utils(alu_transaction)
  rand logic [7:0] a, b;
  rand logic [1:0] op;
  logic [7:0] result;
  function new(string name = "alu_transaction");
    super.new(name);
  endfunction
endclass

// Sequence
class alu_sequence extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(alu_sequence)
  function new(string name = "alu_sequence");
    super.new(name);
  endfunction
  task body();
    alu_transaction tx;
    repeat(100) begin
      tx = alu_transaction::type_id::create("tx");
      start_item(tx);
      void'(tx.randomize());
      finish_item(tx);
    end
  endtask
endclass

// Driver
class alu_driver extends uvm_driver #(alu_transaction);
  `uvm_component_utils(alu_driver)
  virtual alu_if vif;
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRIVER", "Could not get virtual interface")
  endfunction
  task run_phase(uvm_phase phase);
    forever begin
      alu_transaction tx;
      seq_item_port.get_next_item(tx);
      @(posedge vif.clk);
      vif.a  <= tx.a;
      vif.b  <= tx.b;
      vif.op <= tx.op;
      @(posedge vif.clk);
      #1;
      tx.result = vif.result;
      seq_item_port.item_done();
    end
  endtask
endclass

// Monitor
class alu_monitor extends uvm_monitor;
  `uvm_component_utils(alu_monitor)
  virtual alu_if vif;
  uvm_analysis_port #(alu_transaction) ap;
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif))
      `uvm_fatal("MONITOR", "Could not get virtual interface")
  endfunction
  task run_phase(uvm_phase phase);
    forever begin
      alu_transaction tx = alu_transaction::type_id::create("tx");
      @(posedge vif.clk);
      #1;
      tx.a      = vif.a;
      tx.b      = vif.b;
      tx.op     = vif.op;
      tx.result = vif.result;
      ap.write(tx);
    end
  endtask
endclass

// Scoreboard
class alu_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_scoreboard)
  uvm_analysis_imp #(alu_transaction, alu_scoreboard) analysis_export;
  int pass, fail;
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction
  function void write(alu_transaction tx);
    logic [7:0] expected;
    case (tx.op)
      2'b00: expected = tx.a + tx.b;
      2'b01: expected = tx.a - tx.b;
      2'b10: expected = tx.a & tx.b;
      2'b11: expected = tx.a | tx.b;
      default: expected = 8'hxx;
    endcase
    if (tx.result === expected) begin
      `uvm_info("SCOREBOARD", $sformatf("PASS: a=%0d b=%0d op=%0b result=%0d", tx.a, tx.b, tx.op, tx.result), UVM_LOW)
      pass++;
    end else begin
      `uvm_error("SCOREBOARD", $sformatf("FAIL: a=%0d b=%0d op=%0b expected=%0d got=%0d", tx.a, tx.b, tx.op, expected, tx.result))
      fail++;
    end
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("SCOREBOARD", $sformatf("TEST COMPLETE: %0d PASSED, %0d FAILED", pass, fail), UVM_NONE)
  endfunction
endclass

// Environment
class alu_env extends uvm_env;
  `uvm_component_utils(alu_env)
  alu_driver     driver;
  alu_monitor    monitor;
  alu_scoreboard scoreboard;
  uvm_sequencer #(alu_transaction) sequencer;
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    driver     = alu_driver::type_id::create("driver", this);
    monitor    = alu_monitor::type_id::create("monitor", this);
    scoreboard = alu_scoreboard::type_id::create("scoreboard", this);
    sequencer  = uvm_sequencer #(alu_transaction)::type_id::create("sequencer", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
    monitor.ap.connect(scoreboard.analysis_export);
  endfunction
endclass

// Test
class alu_test extends uvm_test;
  `uvm_component_utils(alu_test)
  alu_env env;
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = alu_env::type_id::create("env", this);
  endfunction
  task run_phase(uvm_phase phase);
    alu_sequence seq = alu_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.sequencer);
    phase.drop_objection(this);
  endtask
endclass

// Top module
module tb_top;
  logic clk;
  initial clk = 0;
  always #5 clk = ~clk;

  alu_if dut_if(.clk(clk));

  alu dut(
    .a(dut_if.a),
    .b(dut_if.b),
    .op(dut_if.op),
    .result(dut_if.result)
  );

  initial begin
    uvm_config_db #(virtual alu_if)::set(uvm_root::get(), "*", "vif", dut_if);
    run_test("alu_test");
  end
endmodule
