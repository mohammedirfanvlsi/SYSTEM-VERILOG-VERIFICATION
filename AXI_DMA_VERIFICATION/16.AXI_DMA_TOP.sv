
    // ============================================================================
    // File Name:    tb_top.sv
    // Project:      AXI DMA Controller Design and Verification
    // Description:  Top-level testbench: Clock, Reset, Interface, DUT, and Test launch
    // ============================================================================

    `timescale 1ns / 1ps

    module tb_top;

        // ------------------------------------------------------------------------
        // 1. PARAMETERS & CLOCK / RESET GENERATION
        // ------------------------------------------------------------------------
        parameter DATA_WIDTH = 32; // 32-bit data
        parameter ADDR_WIDTH = 32; // 32-bit address

        // Physical clock and reset wires
        bit clk;
        bit reset_n;

        // 100MHz Clock Generation: Toggles every 5ns (Period = 10ns)
        initial begin
            clk = 1'b0;
            forever #5 clk = ~clk;
        end

        // Power-on Reset Generation:
        // Starts at 0 (in reset), waits 25ns, then releases to 1 (normal operation)
        initial begin
            reset_n = 1'b0; // Hold in reset
            #25;
            reset_n = 1'b1; // Release reset!
        end


        // ------------------------------------------------------------------------
        // 2. INSTANTIATE THE PHYSICAL INTERFACE
        // ------------------------------------------------------------------------
        // This is the bundle of wires that connects our testbench to the DUT!
        dma_if #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH)
        ) intf (
            .clk     (clk),
            .reset_n (reset_n)
        );


        // ------------------------------------------------------------------------
        // 3. INSTANTIATE THE HARDWARE DUT (dma_stream_top.v)
        // ------------------------------------------------------------------------
        dma_stream_top #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH)
        ) u_dut (
            // Clock & Reset
            .clk            (intf.clk),
            .reset_n        (intf.reset_n),

            // CPU Slave Control Interface
            .reg_wr_en      (intf.reg_wr_en),
            .reg_addr       (intf.reg_addr),
            .reg_wdata      (intf.reg_wdata),
            .reg_rdata      (intf.reg_rdata),
            .irq            (intf.irq),

            // AXI-Stream Input Interface (Peripheral / Camera stream)
            .s_axis_tdata   (intf.s_axis_tdata),
            .s_axis_tvalid  (intf.s_axis_tvalid),
            .s_axis_tready  (intf.s_axis_tready),
            .s_axis_tlast   (intf.s_axis_tlast),

            // AXI4-Full Master Write Address Channel (AW)
            .m_axi_awid     (intf.m_axi_awid),
            .m_axi_awaddr   (intf.m_axi_awaddr),
            .m_axi_awlen    (intf.m_axi_awlen),
            .m_axi_awsize   (intf.m_axi_awsize),
            .m_axi_awburst  (intf.m_axi_awburst),
            .m_axi_awvalid  (intf.m_axi_awvalid),
            .m_axi_awready  (intf.m_axi_awready),

            // AXI4-Full Master Write Data Channel (W)
            .m_axi_wdata    (intf.m_axi_wdata),
            .m_axi_wstrb    (intf.m_axi_wstrb),
            .m_axi_wlast    (intf.m_axi_wlast),
            .m_axi_wvalid   (intf.m_axi_wvalid),
            .m_axi_wready   (intf.m_axi_wready),

            // AXI4-Full Master Write Response Channel (B)
            .m_axi_bid      (intf.m_axi_bid),
            .m_axi_bresp    (intf.m_axi_bresp),
            .m_axi_bvalid   (intf.m_axi_bvalid),
            .m_axi_bready   (intf.m_axi_bready),

            // AXI4-Full Master Read Channels (Tied off / unused in write-only DMA)
            .m_axi_arid     (),
            .m_axi_araddr   (),
            .m_axi_arlen    (),
            .m_axi_arsize   (),
            .m_axi_arburst  (),
            .m_axi_arvalid  (),
            .m_axi_arready  (1'b0),
            .m_axi_rid      (4'd0),
            .m_axi_rdata    (32'd0),
            .m_axi_rresp    (2'd0),
            .m_axi_rlast    (1'b0),
            .m_axi_rvalid   (1'b0),
            .m_axi_rready   ()
        );


        // ------------------------------------------------------------------------
        // 4. INSTANTIATE MEMORY MODEL SLAVE (axi_slave.v)
        // ------------------------------------------------------------------------
        // Acts as the RAM memory receiving and acknowledging the DMA writes
        axi_slave #(
            .DATA_WIDTH (DATA_WIDTH),
            .ADDR_WIDTH (ADDR_WIDTH),
            .ID_WIDTH   (4)
        ) u_mem (
            .aclk           (intf.clk),
            .aresetn        (intf.reset_n),

            // Connect AXI Write Channels directly to interface
            .s_axi_awid     (intf.m_axi_awid),
            .s_axi_awaddr   (intf.m_axi_awaddr),
            .s_axi_awlen    (intf.m_axi_awlen),
            .s_axi_awsize   (intf.m_axi_awsize),
            .s_axi_awburst  (intf.m_axi_awburst),
            .s_axi_awvalid  (intf.m_axi_awvalid),
            .s_axi_awready  (intf.m_axi_awready),

            .s_axi_wdata    (intf.m_axi_wdata),
            .s_axi_wstrb    (intf.m_axi_wstrb),
            .s_axi_wlast    (intf.m_axi_wlast),
            .s_axi_wvalid   (intf.m_axi_wvalid),
            .s_axi_wready   (intf.m_axi_wready),

            .s_axi_bid      (intf.m_axi_bid),
            .s_axi_bresp    (intf.m_axi_bresp),
            .s_axi_bvalid   (intf.m_axi_bvalid),
            .s_axi_bready   (intf.m_axi_bready),

            // Read channels unused
            .s_axi_arid     (4'd0),
            .s_axi_araddr   (32'd0),
            .s_axi_arlen    (8'd0),
            .s_axi_arsize   (3'd0),
            .s_axi_arburst  (2'd0),
            .s_axi_arvalid  (1'b0),
            .s_axi_arready  (),
            .s_axi_rid      (),
            .s_axi_rdata    (),
            .s_axi_rresp    (),
            .s_axi_rlast    (),
            .s_axi_rvalid   (),
            .s_axi_rready   (1'b0)
        );


        // ------------------------------------------------------------------------
        // 5. TEST LAUNCHER (Initial Block)
        // ------------------------------------------------------------------------
        // Creates the test object and kicks off the entire verification environment!
        initial begin
            // Declare the test handle
            dma_test test;

            // Create the test and pass our physical interface into it
            test = new(intf);

            // Run the complete test!
            test.run();
        end


        // ------------------------------------------------------------------------
        // 6. WAVEFORM DUMPING (For GTKWave / Vivado debugging)
        // ------------------------------------------------------------------------
        initial begin
            $dumpfile("dma_sv_tb.vcd"); // Save waveform to this file
            $dumpvars(0, tb_top);       // Dump all variables in tb_top and submodules
        end

    endmodule
