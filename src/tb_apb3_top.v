`timescale 1ns / 1ps
module tb_apb;
    // Signals
    reg         pclk, presetn;
    reg         start, write;
    reg [31:0]  addr, wdata;
    reg [3:0]   strb;
    reg [2:0]   prot;
    wire [31:0] rdata;
    wire        done, error;

    apb_top dut (
        .pclk    (pclk),
        .presetn (presetn),
        .start   (start),
        .write   (write),
        .addr    (addr),
        .wdata   (wdata),
        .strb    (strb),
        .prot    (prot),
        .rdata   (rdata),
        .done    (done),
        .error   (error)
    );

    initial begin
        pclk = 0;
        forever #5 pclk = ~pclk;
    end
    
    task apb_write(input [31:0] a, input [31:0] d);
    begin
        @(posedge pclk);
        addr  = a;
        wdata = d;
        write = 1;
        strb  = 4'b1111;      // full-word
        prot  = 3'b000;
        start = 1;
        @(posedge pclk);
        start = 0;

        // Wait for master.done
        wait (done);
        $display("WRITE @ %h = %h    error = %b", a, d, error);

        // Give the bus 3 idle cycles to let slave finish its wait-states & write
        repeat (3) @(posedge pclk);

        // Clear start/write for safety
        write = 0;
    end
    endtask

    task apb_read(input [31:0] a);
    begin
        @(posedge pclk);
        addr  = a;
        write = 0;
        strb  = 4'b0000;
        prot  = 3'b000;
        start = 1;
        @(posedge pclk);
        start = 0;

        // Wait for master.done
        wait (done);
        $display("READ  @ %h = %h    error = %b", a, rdata, error);

        // Give 3 cycles before next transaction
        repeat (3) @(posedge pclk);
    end
    endtask

    initial begin
        $display("========== Starting APB Bus Test ==========");
        // Init
        start = 0; write = 0; addr = 0; wdata = 0;
        strb  = 4'b0000; prot  = 3'b000;

        // Reset sequence
        presetn = 0;
        repeat (2) @(posedge pclk);
        presetn = 1;
        $display("RESET done");

        // ---- Slave 0 tests ----
        apb_write(32'h0000_0000, 32'hDEADBEAD);
        apb_write(32'h0000_0004, 32'hCAFEBABA);
        apb_read (32'h0000_0000);
        apb_read (32'h0000_0004);

        // ---- Slave 1 tests ----
        apb_write(32'h0000_1000, 32'h11223344);
        apb_write(32'h0000_1004, 32'hAABBCCDD);
        apb_read (32'h0000_1000);
        apb_read (32'h0000_1004);

        // ---- Invalid address (should set error) ----
        apb_read (32'h0000_3000);

        $display("========== APB Bus Test Completed ==========");
        $stop;
    end

endmodule
