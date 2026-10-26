  // ============================================================================
    // File Name:    dma_driver.sv
    // Project:      AXI DMA Controller Design and Verification
    // Description:  Configures CPU registers and drives AXI-Stream packets into DMA
    // ============================================================================

    `timescale 1ns / 1ps

    class dma_driver;

        // ------------------------------------------------------------------------
        // 1. CLASS VARIABLES & HANDLES
        // ------------------------------------------------------------------------
        virtual dma_if.DRIVER vif;
        mailbox #(dma_transaction) mbx_drv;


        // ------------------------------------------------------------------------
        // 2. CONSTRUCTOR
        // ------------------------------------------------------------------------
        function new(virtual dma_if.DRIVER vif, mailbox #(dma_transaction) mbx_drv);
            this.vif     = vif;
            this.mbx_drv = mbx_drv;
        endfunction


        // ------------------------------------------------------------------------
        // 3. RESET TASK
        // ------------------------------------------------------------------------
        task reset();
            // Wait until reset is released
            wait(vif.reset_n == 1'b1);
            @(vif.drv_cb);

            // Clear CPU signals
            vif.drv_cb.reg_wr_en <= 1'b0;
            vif.drv_cb.reg_addr  <= 4'h0;
            vif.drv_cb.reg_wdata <= 32'h0;

            // Clear Stream signals
            vif.drv_cb.s_axis_tdata  <= 32'h0;
            vif.drv_cb.s_axis_tvalid <= 1'b0;
            vif.drv_cb.s_axis_tlast  <= 1'b0;
        endtask


        // ------------------------------------------------------------------------
        // 4. CPU CONFIGURATION TASK (Sets Destination Address & Starts DMA)
        // ------------------------------------------------------------------------
        task configure_dma(bit [31:0] dest_addr);

            // Step 1: Write Destination Address into Register 0x4
            @(vif.drv_cb);
            vif.drv_cb.reg_addr  <= 4'h4;        // Register 0x4 = DST_ADDR
            vif.drv_cb.reg_wdata <= dest_addr;   // Pass the real memory address!
            vif.drv_cb.reg_wr_en <= 1'b1;        // Pulse write enable
            @(vif.drv_cb);
            vif.drv_cb.reg_wr_en <= 1'b0;

            // Step 2: Write START command into Control Register 0xC
            @(vif.drv_cb);
            vif.drv_cb.reg_addr  <= 4'hC;        // Register 0xC = CTRL
            vif.drv_cb.reg_wdata <= 32'h1;       // Bit 0 = 1 (START DMA!)
            vif.drv_cb.reg_wr_en <= 1'b1;
            @(vif.drv_cb);
            vif.drv_cb.reg_wr_en <= 1'b0;

            $display("[%0t] [CPU DRIVER] Configured DMA: Destination Address = 0x%08h, START = 1", $time, dest_addr);
        endtask


        // ------------------------------------------------------------------------
        // 5. MAIN STREAM DRIVE TASK
        // ------------------------------------------------------------------------
        task main();
            dma_transaction trans;

            forever begin
                // Get packet from Generator
                mbx_drv.get(trans);

                // Wait for clock edge
                @(vif.drv_cb);

                // Drive packet to stream input
                vif.drv_cb.s_axis_tdata  <= trans.tdata;
                vif.drv_cb.s_axis_tvalid <= 1'b1;
                vif.drv_cb.s_axis_tlast  <= trans.tlast;

                trans.display("DRIVER");

                // Wait until DMA accepts the word (s_axis_tready == 1)
                @(vif.drv_cb);
                while (!vif.drv_cb.s_axis_tready) begin
                    @(vif.drv_cb);
                end

                // Handshake done! Pull valid low
                vif.drv_cb.s_axis_tvalid <= 1'b0;
                vif.drv_cb.s_axis_tlast  <= 1'b0;
            end
        endtask

    endclass
