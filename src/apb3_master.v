`timescale 1ns / 1ps
module apb_master(
    input pclk, presetn, pready, pslverr, 
    input [31:0] prdata,wdata,addr,
    input start,write,
    input [3:0] strb,
    input [2:0] prot,
    output reg psel,penable,pwrite,
    output reg [31:0] paddr,pwdata,
    output reg [3:0] pstrb,
    output reg [2:0] pprot,
    output reg done,error,
    output reg [31:0] rdata
    );
    parameter idle=2'b00,
              setup=2'b01,
              access=2'b10;
    reg [1:0] state, next;  
    always @(posedge pclk, negedge presetn) 
    begin
        if(!presetn) state<=idle;
        else state<=next;
    end 
    always @(*) begin
        case(state)
        idle: next = start?setup:idle;
        setup: next = access;
        access: next=pready?idle:access;
        default: next=idle;
    endcase    
    end 
    always @(posedge pclk,negedge presetn)
    begin
        if(!presetn) begin
        psel<=0;
        penable<=0;
        done<=0;
        error<=0;
        paddr <= 0;
        pwrite <= 0;
        pwdata <= 0;
        pstrb <= 0;
        pprot <= 0;
        rdata <= 0;
        end else begin
        case(state)
        idle: begin
            done<=0;
            error<=0;
            psel<=0;
            penable<=0;

        end
        setup: begin
            psel<=1;
            penable<=0;
            paddr<=addr;
            pwrite<=write;
            pwdata<=wdata;
            pstrb<=strb;
            pprot<=prot;
            
        end
        access: begin
            penable<=1;
            if(pready) begin
                done<=1;
                error<=pslverr;
                if(!write) rdata<=prdata;
            end
        end
    endcase
    end
    end      
endmodule
