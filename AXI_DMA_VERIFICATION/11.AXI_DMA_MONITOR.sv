
    // ============================================================================
    // File Name:    dma_monitor.sv
    // Project:      AXI DMA Controller Design and Verification
    // Description:  Monitors AXI4-Full write transactions from DMA and sends to Scoreboard
    // ============================================================================

    `timescale 1ns / 1ps

    class dma_monitor;

        // ------------------------------------------------------------------------
        // 1. CLASS VARIABLES & HANDLES
        // ------------------------------------------------------------------------

        // Virtual interface handle (read-only view to listen to physical wires)
        virtual dma_if.MONITOR vif;

        // Mailbox handle to send captured data to the Scoreboard
        mailbox #(dma_transaction) mbx_scb;
        mailbox #(dma_transaction) mbx_cov;

        // Internal variable to store the latest write address from AW channel
        logic [31:0] captured_addr;


        // ------------------------------------------------------------------------
        // 2. CONSTRUCTOR (new function)
        // ------------------------------------------------------------------------
        // Connects the virtual interface and Scoreboard mailbox to this monitor
       function new(virtual dma_if.MONITOR vif,
                     mailbox #(dma_transaction) mbx_scb,
                     mailbox #(dma_transaction) mbx_cov);
            this.vif     = vif;
            this.mbx_scb = mbx_scb;
            this.mbx_cov = mbx_cov;
        endfunction


        // ------------------------------------------------------------------------
        // 3. MAIN MONITOR TASK
        // ------------------------------------------------------------------------
        task main();
            // Transaction handle to store captured memory data
            dma_transaction trans;

            // Run continuously throughout simulation
            forever begin

                // Wait for the next rising clock edge using monitor clocking block
                @(vif.mon_cb);

                // ----------------------------------------------------------------
                // CHECK 1: Sample Write Address (AW Channel Handshake)
                // When AWVALID=1 and AWREADY=1, the DMA has sent a destination address!
                // ----------------------------------------------------------------
                if (vif.mon_cb.m_axi_awvalid && vif.mon_cb.m_axi_awready) begin
                    captured_addr = vif.mon_cb.m_axi_awaddr; // Save the memory address
                end

                // ----------------------------------------------------------------
                // CHECK 2: Sample Write Data (W Channel Handshake)
                // When WVALID=1 and WREADY=1, a 32-bit data word is written to memory!
                // ----------------------------------------------------------------
                if (vif.mon_cb.m_axi_wvalid && vif.mon_cb.m_axi_wready) begin

                    // Create a new transaction packet to hold the observed output
                    trans = new();

                    // Grab the data written by the DMA
                    trans.tdata = vif.mon_cb.m_axi_wdata;

                    // Grab the last beat flag (WLAST)
                    trans.tlast = vif.mon_cb.m_axi_wlast;

                    // Attach the captured memory address for Address Increment check
                    trans.addr  = captured_addr;

                    // Print captured output to terminal
                    trans.display("MONITOR");

                    // Put the captured packet into the Scoreboard mailbox for checking!
                    mbx_scb.put(trans);
                  
                  
                    // Send to Coverage for functional coverage measurement
                    mbx_cov.put(trans);

                end // end of if (WVALID && WREADY)

            end // end of forever loop
        endtask

    endclass
