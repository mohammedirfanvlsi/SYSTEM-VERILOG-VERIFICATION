
    // ============================================================================
    // File Name:    dma_test.sv
    // Project:      AXI DMA Controller Design and Verification
    // Description:  Configures test parameters and runs the verification environment
    // ============================================================================

    `timescale 1ns / 1ps

    class dma_test;

        // ------------------------------------------------------------------------
        // 1. CLASS VARIABLES & HANDLES
        // ------------------------------------------------------------------------

        // Handle to the complete verification environment
        dma_env env;

        // Virtual interface handle to pass down to the environment
        virtual dma_if vif;


        // ------------------------------------------------------------------------
        // 2. CONSTRUCTOR
        // ------------------------------------------------------------------------
        // Instantiates the environment and connects the physical interface
        function new(virtual dma_if vif);
            this.vif = vif;       // Connect interface
            env      = new(vif);  // Create the environment object in memory
        endfunction


        // ------------------------------------------------------------------------
        // 3. MAIN RUN TASK
        // ------------------------------------------------------------------------
        task run();

            // Print a nice banner to terminal showing test start
            $display("\n=======================================================");
            $display("   STARTING AXI DMA CONTROLLER VERIFICATION TEST      ");
            $display("   TESTCASE 1: Data Match Verification                ");
            $display("   TESTCASE 2: Address Increment (+16 bytes) Check    ");
            $display("=======================================================\n");

            // Set how many total words the Generator should create:
            // count = 8 means:
            // - Burst 1: 4 words written to 0x8000_0000
            // - Burst 2: 4 words written to 0x8000_0010 (+16 bytes!)
            // This tests both Testcase 1 (data match) and Testcase 2 (address increment)!
            env.gen.count = 12;

            // Run the 3 phases of the environment:
            // 1. pre_test (Reset chip & configure CPU registers)
            // 2. test     (Run Generator, Driver, Monitor, Scoreboard, Coverage)
            // 3. post_test(Wait for completion & print PASS/FAIL report)
            env.run();

            $display("\n[TEST COMPLETED] Simulation Finished Successfully!\n");

        endtask

    endclass
