
    // ============================================================================
    // File Name:    dma_if.sv
    // Project:      AXI DMA Controller Design and Verification
    // Description:  Complete DMA Top-Level Interface (Stream + CPU + AXI4-Full)
    // ============================================================================

    `timescale 1ns / 1ps

    interface dma_if #(
        parameter DATA_WIDTH = 32, // 32-bit data words
        parameter ADDR_WIDTH = 32  // 32-bit memory addresses
    )(
        input logic clk,           // Clock signal
        input logic reset_n        // Active-low reset (0 = reset, 1 = normal)
    );

        // ------------------------------------------------------------------------
        // 1. CPU SLAVE CONTROL SIGNALS
        // ------------------------------------------------------------------------
        logic                  reg_wr_en; // CPU write enable (1 = write to register)
        logic [3:0]            reg_addr;  // Register address (e.g. 0x0=CTRL, 0x4=DST_ADDR)
        logic [DATA_WIDTH-1:0] reg_wdata; // Data written by CPU
        logic [DATA_WIDTH-1:0] reg_rdata; // Data read by CPU (status)
        logic                  irq;       // Interrupt line (DMA tells CPU: "I am done!")

        // ------------------------------------------------------------------------
        // 2. AXI-STREAM INPUT SIGNALS (Peripheral / Camera side)
        // ------------------------------------------------------------------------
        logic [DATA_WIDTH-1:0] s_axis_tdata;  // Incoming streaming pixel/data
        logic                  s_axis_tvalid; // Stream data valid
        logic                  s_axis_tready; // DMA ready (FIFO has space)
        logic                  s_axis_tlast;  // End of frame / packet marker

        // ------------------------------------------------------------------------
        // 3. AXI4-FULL MASTER WRITE SIGNALS (Memory / RAM side)
        // ------------------------------------------------------------------------
        // (A) Write Address Channel (AW)
        logic [3:0]            m_axi_awid;    // Transaction ID tag
        logic [ADDR_WIDTH-1:0] m_axi_awaddr;  // Destination memory address
        logic [7:0]            m_axi_awlen;   // Burst length (e.g. 3 means 4 beats)
        logic [2:0]            m_axi_awsize;  // Bytes per beat (e.g. 3'b010 = 4 bytes)
        logic [1:0]            m_axi_awburst; // Burst type (e.g. 2'b01 = INCR)
        logic                  m_axi_awvalid; // Master address valid
        logic                  m_axi_awready; // Memory ready to accept address

        // (B) Write Data Channel (W)
        logic [DATA_WIDTH-1:0] m_axi_wdata;   // Actual data word being written
        logic [3:0]            m_axi_wstrb;   // Byte strobes (usually 4'b1111)
        logic                  m_axi_wlast;   // Last data beat in the burst
        logic                  m_axi_wvalid;  // Master write data valid
        logic                  m_axi_wready;  // Memory ready to accept data

        // (C) Write Response Channel (B)
        logic [3:0]            m_axi_bid;     // Response ID tag
        logic [1:0]            m_axi_bresp;   // Response status (00 = OKAY)
        logic                  m_axi_bvalid;  // Memory response valid
        logic                  m_axi_bready;  // Master ready to receive response


        // ------------------------------------------------------------------------
        // 4. CLOCKING BLOCKS (Timing & Race Condition Elimination)
        // ------------------------------------------------------------------------

        // (A) DRIVER CLOCKING BLOCK:
        // The Driver SENDS data to the DMA, so it drives outputs.
        clocking drv_cb @(posedge clk);
            default input #1ns output #1ns;
            // CPU Control (Driver writes to DMA registers)
            output reg_wr_en, reg_addr, reg_wdata;
            input  reg_rdata, irq;

            // AXI-Stream (Driver feeds camera data into DMA)
            output s_axis_tdata, s_axis_tvalid, s_axis_tlast;
            input  s_axis_tready;

            
        endclocking

        // (B) MONITOR CLOCKING BLOCK:
        // The Monitor ONLY LISTENS (every single signal is an INPUT).
        clocking mon_cb @(posedge clk);
            default input #1ns output #1ns;
            input reg_wr_en, reg_addr, reg_wdata, reg_rdata, irq;
            input s_axis_tdata, s_axis_tvalid, s_axis_tready, s_axis_tlast;
            input m_axi_awaddr, m_axi_awlen, m_axi_awvalid, m_axi_awready;
            input m_axi_wdata, m_axi_wlast, m_axi_wvalid, m_axi_wready;
            input m_axi_bvalid, m_axi_bready;
        endclocking


        // ------------------------------------------------------------------------
        // 5. MODPORTS (Direction rules for each testbench component)
        // ------------------------------------------------------------------------

        // Driver View: Uses driver clocking block
        modport DRIVER (
            clocking drv_cb,
            input    reset_n
        );

        // Monitor View: Uses monitor clocking block (read-only)
        modport MONITOR (
            clocking mon_cb,
            input    reset_n
        );

        // DUT View: Wires directly into the RTL ports of dma_stream_top.v
        modport DUT (
            input  clk, reset_n,
            // CPU
            input  reg_wr_en, reg_addr, reg_wdata,
            output reg_rdata, irq,
            // Stream
            input  s_axis_tdata, s_axis_tvalid, s_axis_tlast,
            output s_axis_tready,
            // AXI-Full Master Write
            output m_axi_awid, m_axi_awaddr, m_axi_awlen, m_axi_awsize, m_axi_awburst, m_axi_awvalid,
            input  m_axi_awready,
            output m_axi_wdata, m_axi_wstrb, m_axi_wlast, m_axi_wvalid,
            input  m_axi_wready,
            input  m_axi_bid, m_axi_bresp, m_axi_bvalid,
            output m_axi_bready
        );


        // ------------------------------------------------------------------------
        // 6. SYSTEMVERILOG ASSERTIONS (SVA - Protocol Watchdogs)
        // ------------------------------------------------------------------------

        // Assertion 1: Stream Stability
        // If TVALID is 1 and TREADY is 0, TVALID and TDATA must stay unchanged.
        property p_stream_stable;
            @(posedge clk) disable iff (!reset_n)
            (s_axis_tvalid && !s_axis_tready) |=> (s_axis_tvalid && $stable(s_axis_tdata));
        endproperty
        assert_stream_stable: assert property (p_stream_stable)
            else $error("[SVA ERROR @ %0t] Stream data/valid changed while TREADY was low!", $time);

        // Assertion 2: AXI-Full Address Stability
        // If AWVALID is 1 and AWREADY is 0, AWADDR must stay unchanged until accepted.
        property p_awaddr_stable;
            @(posedge clk) disable iff (!reset_n)
            (m_axi_awvalid && !m_axi_awready) |=> (m_axi_awvalid && $stable(m_axi_awaddr));
        endproperty
        assert_awaddr_stable: assert property (p_awaddr_stable)
            else $error("[SVA ERROR @ %0t] AXI AWADDR changed while AWREADY was low!", $time);

    endinterface : dma_if
