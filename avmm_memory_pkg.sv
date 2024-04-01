package avmm_memory_pkg;

localparam DATA_WIDTH = 512;
localparam CAPACITY = 8*1024*1024*1024;
localparam DATA_WIDTH_IN_BYTES = DATA_WIDTH / 8;

// width: 624
typedef struct packed {
    logic read;
    logic write;
    logic [51:6] address;
    logic [DATA_WIDTH_IN_BYTES - 1:0] byteenable;
    logic [DATA_WIDTH-1:0] writedata;
    logic [63:0] timestamp;
} avmm_req;

// width: 513
typedef struct packed {
    logic readdatavalid;
    logic [DATA_WIDTH-1:0] readdata;
} avmm_rsp;

endpackage