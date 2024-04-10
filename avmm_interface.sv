import avmm_memory_pkg::*;

module avmm_interface_memory #(
    parameter LATENCY = 100
)(
    input logic clk,
    input logic rstn,
    input logic read,
    input logic write,
    input logic [51:6] address,
    input logic [DATA_WIDTH_IN_BYTES - 1:0] byteenable,
    input logic [DATA_WIDTH-1:0] writedata,

    output logic [DATA_WIDTH-1:0] readdata,
    output logic readdatavalid,
    output logic ready
);

    // Memory
    logic [DATA_WIDTH:0] memory [CAPACITY - 1:0];

    initial begin
        integer i;
        for (i = 0; i < CAPACITY; i = i + 1) begin
            logic [31:0] pfn = i;
            memory[i] = {16{pfn}};
        end
    end

    // timestamp logic
    logic [64:0] timestamp;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            timestamp <= 1'b0;
        end 
        else begin
            timestamp <= timestamp + 1;
        end
    end

    // fifo for requests
    logic req_fifo_full;
    logic req_fifo_empty;
    logic [$clog2(64):0] req_fifo_usage;
    avmm_req req_fifo_data_i;
    avmm_req req_fifo_data_o;
    logic req_fifo_push;
    logic req_fifo_pop;

    always_comb begin
        req_fifo_data_i.read = read;
        req_fifo_data_i.write = write;
        req_fifo_data_i.address = address;
        req_fifo_data_i.byteenable = byteenable;
        req_fifo_data_i.writedata = writedata;
        req_fifo_data_i.timestamp = timestamp;
    end

    always_comb begin
        req_fifo_push = read | write;
        req_fifo_pop = (~req_fifo_empty) & ((req_fifo_data_o.timestamp + LATENCY) <= timestamp);
    end

    always_comb begin
        if (req_fifo_usage >= 57) begin
            ready = 0;
        end
        else begin
            ready = 1;
        end

        readdatavalid = req_fifo_pop & req_fifo_data_o.read;
        
        if (readdatavalid)
            readdata = memory[req_fifo_data_o.address];
        else
            readdata = 0;
    end

    // mask logic
    logic [DATA_WIDTH:0] mask;
    always_comb begin
        mask = 0;
        for (int i = 0; i < DATA_WIDTH_IN_BYTES; i++) begin
            mask = mask << 8;
            mask[7:0] = req_fifo_data_o.byteenable[DATA_WIDTH_IN_BYTES - i - 1] ? 8'hFF : 8'h00;
        end
    end

    // write logic
    always_ff @(posedge clk) begin
        if (req_fifo_pop & req_fifo_data_o.write) begin
            memory[req_fifo_data_o.address] <= (req_fifo_data_o.writedata & mask) | (memory[req_fifo_data_o.address] & ~mask);
        end
    end

    fifo_v3 #(
        .DATA_WIDTH(688),
        .DEPTH(64)
    ) req_fifo (
        .clk_i(clk),
        .rst_ni(rstn),
        .flush_i(0),
        .full_o(req_fifo_full),
        .empty_o(req_fifo_empty),
        .usage_o(req_fifo_usage),
        .data_i(req_fifo_data_i),
        .push_i(req_fifo_push),
        .data_o(req_fifo_data_o),
        .pop_i(req_fifo_pop)
    );


endmodule

module avmm_interface_memory_multi_channel #(
    parameter LATENCY = 100,
    parameter CHANNELS = 2
)(
    input logic clk,
    input logic rstn,
    input logic [CHANNELS-1:0] read,
    input logic [CHANNELS-1:0] write,
    input logic [51:6] address [CHANNELS-1:0],
    input logic [DATA_WIDTH_IN_BYTES - 1:0] byteenable [CHANNELS-1:0],
    input logic [DATA_WIDTH-1:0] writedata [CHANNELS-1:0],

    output logic [DATA_WIDTH-1:0] readdata [CHANNELS-1:0],
    output logic [CHANNELS-1:0] readdatavalid,
    output logic [CHANNELS-1:0] ready
);

    generate
        for (genvar i = 0; i < CHANNELS; i++) begin
            avmm_interface_memory #(
                .LATENCY(LATENCY)
            ) avmm_interface_memory_inst(
                .clk(clk),
                .rstn(rstn),
                .read(read[i]),
                .write(write[i]),
                .address(address[i]),
                .byteenable(byteenable[i]),
                .writedata(writedata[i]),
                .readdata(readdata[i]),
                .readdatavalid(readdatavalid[i]),
                .ready(ready[i])
            );
        end
    endgenerate

endmodule