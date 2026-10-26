  // ============================================================================
    // File Name:    dma_env.sv
    // Project:      AXI DMA Controller Design and Verification
    // Description:  Connects Generator, Driver, Monitor, Scoreboard, and Coverage
    // ============================================================================

    `timescale 1ns / 1ps

    class dma_env;

        // ------------------------------------------------------------------------
        // 1. COMPONENT HANDLES
        // ------------------------------------------------------------------------
        dma_generator  gen;  // Generator handle
        dma_driver     drv;  // Driver handle
        dma_monitor    mon;  // Monitor handle
        dma_scoreboard scb;  // Scoreboard handle
        dma_coverage   cov;  // Coverage handle

        // ------------------------------------------------------------------------
        // 2. MAILBOX HANDLES (The communication pipes)
        // ------------------------------------------------------------------------
        mailbox #(dma_transaction) mbx_drv;      // Generator -> Driver
        mailbox #(dma_transaction) mbx_scb_gen;  // Generator -> Scoreboard (Expected data)
        mailbox #(dma_transaction) mbx_scb_mon;  // Monitor   -> Scoreboard (Actual data)
        mailbox #(dma_transaction) mbx_cov;      // Monitor   -> Coverage

        // Virtual interface handle to physical wires
        virtual dma_if vif;


        // ------------------------------------------------------------------------
        // 3. CONSTRUCTOR
        // ------------------------------------------------------------------------
        function new(virtual dma_if vif);
            this.vif = vif; // Connect the interface

            // Step 1: Create all 4 mailboxes in memory
            mbx_drv     = new();
            mbx_scb_gen = new();
            mbx_scb_mon = new();
            mbx_cov     = new();

            // Step 2: Create all components and connect their mailboxes!
            gen = new(mbx_drv, mbx_scb_gen);          // Generator gets Driver & Scoreboard mailboxes
            drv = new(vif, mbx_drv);                  // Driver gets interface & Driver mailbox
            mon = new(vif, mbx_scb_mon, mbx_cov);     // Monitor gets interface, Scoreboard & Coverage mailboxes
            scb = new(mbx_scb_gen, mbx_scb_mon);      // Scoreboard gets Expected & Actual mailboxes
            cov = new(mbx_cov);                       // Coverage gets Coverage mailbox
        endfunction


        // ------------------------------------------------------------------------
        // 4. PHASE 1: PRE-TEST (Reset & CPU Register Setup)
        // ------------------------------------------------------------------------
        task pre_test();
            // Reset the chip
            drv.reset();

            // Configure the CPU registers: Set Destination Address to 0x8000_0000 and START DMA!
            drv.configure_dma(32'h8000_0000);
        endtask


        // ------------------------------------------------------------------------
        // 5. PHASE 2: TEST (Run all components in parallel)
        // ------------------------------------------------------------------------
        task test();
            fork
                gen.main();  // Start generating packets
                drv.main();  // Start driving stream wires
                mon.main();  // Start monitoring memory writes
                scb.main();  // Start checking data match & address increment
                cov.main();  // Start measuring coverage
            join_any
        endtask


        // ------------------------------------------------------------------------
        // 6. PHASE 3: POST-TEST (Wait for finish & Print Reports)
        // ------------------------------------------------------------------------
        task post_test();
            // Wait until Generator finishes generating all words
            wait(gen.ended.triggered);

            wait(scb.match_count + scb.mismatch_count == gen.count);
 
          // Wait a small delay for the last memory write burst to settle in RAM
            #200;

            // Print final reports!
            scb.report();            // Prints PASS / FAIL for Testcase 1 and 2
            cov.display_coverage();  // Prints final Functional Coverage score (%)
        endtask


        // ------------------------------------------------------------------------
        // 7. MAIN RUN TASK (Executes all 3 phases in order)
        // ------------------------------------------------------------------------
        task run();
            pre_test();   // Step 1: Reset & Configure
            test();       // Step 2: Run all blocks
            post_test();  // Step 3: Check results & display report
            $finish;      // End simulation cleanly!
        endtask

    endclass
