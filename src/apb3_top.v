`timescale 1ns / 1ps
module apb_top(
    input        pclk,
    input        presetn,
    input        start,
    input        write,
    input [31:0] addr,
    input [31:0] wdata,
    input [3:0]  strb,
    input [2:0]  prot,
    output [31:0] rdata,
    output        done,
    output        error
);
    //Wires between master and slaves
    wire        psel;
    wire        penable;
    wire        pwrite;
    wire [31:0] paddr;
    wire [31:0] pwdata;
    wire [3:0]  pstrb;
    wire [2:0]  pprot;
    wire [31:0] prdata_int;
    wire        pready_int;
    wire        pslverr_int;
    // Address decode for two slaves
    wire psel0 = psel && (paddr[31:12] == 20'h00000);  // base = 0x0000_0000
    wire psel1 = psel && (paddr[31:12] == 20'h0001);  // base = 0x0000_1000

    // Slave 0 outputs
    wire [31:0] prdata0;
    wire        pready0;
    wire        pslverr0;
    // Slave 1 outputs
    wire [31:0] prdata1;
    wire        pready1;
    wire        pslverr1;
    //Mux PRDATA, PREADY, PSLVERR back to master
    assign prdata_int = psel0 ? prdata0
                      : psel1 ? prdata1
                      : 32'h0000_0000;
    assign pready_int = psel0 ? pready0
                      : psel1 ? pready1
                      : 1'b0;
    assign pslverr_int= psel0 ? pslverr0
                      : psel1 ? pslverr1
                      : 1'b1;
    //Master instantiation
    apb_master master (
        .pclk    (pclk),
        .presetn (presetn),
        .start   (start),
        .write   (write),
        .addr    (addr),
        .wdata   (wdata),
        .strb    (strb),
        .prot    (prot),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr),
        .pwdata  (pwdata),
        .pstrb   (pstrb),
        .pprot   (pprot),
        .done    (done),
        .error   (error),
        .rdata   (rdata),
        .prdata  (prdata_int),
        .pready  (pready_int),
        .pslverr (pslverr_int)
    );
    // Slave 0 (BASE = 0x0000_0000)
    // ------------------------------------------------------------------
    apb_slave #(.base_addr(32'h0000_0000)) slave0 (
        .pclk    (pclk),
        .presetn (presetn),
        .psel    (psel0),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr),
        .pwdata  (pwdata),
        .pstrb   (pstrb),
        .pprot   (pprot),
        .prdata  (prdata0),
        .pready  (pready0),
        .pslverr (pslverr0)
    );
    // Slave 1 (BASE = 0x0000_1000)
    apb_slave #(.base_addr(32'h0000_1000)) slave1 (
        .pclk    (pclk),
        .presetn (presetn),
        .psel    (psel1),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr),
        .pwdata  (pwdata),
        .pstrb   (pstrb),
        .pprot   (pprot),
        .prdata  (prdata1),
        .pready  (pready1),
        .pslverr (pslverr1)
    );

endmodule
