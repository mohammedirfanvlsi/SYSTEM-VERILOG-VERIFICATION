
    // ============================================================================
    // File Name:    dma_scoreboard.sv
    // Project:      AXI DMA Controller Design and Verification
    // Description:  Verifies Testcase 1 (Data Match) and Testcase 2 (Address Increment)
    // ============================================================================

    `timescale 1ns / 1ps

    class dma_scoreboard;

        // ------------------------------------------------------------------------
        // 1. CLASS VARIABLES & HANDLES
        // ------------------------------------------------------------------------

        // Mailbox to receive EXPECTED data from the Generator
        mailbox #(dma_transaction) mbx_gen;

        // Mailbox to receive ACTUAL captured memory data from the Monitor
        mailbox #(dma_transaction) mbx_mon;

        // Queue to hold expected data words in order (FIFO order)
        bit [31:0] expected_queue[$];

        // Variable to track the expected memory address (starts at base address)
        bit [31:0] expected_addr;

        // Counter to track how many words have been received (to detect 4-word burst boundaries)
        int word_count;

        // Statistics counters
        int match_count;     // Counts how many words matched successfully
        int mismatch_count;  // Counts how many words failed to match


        // ------------------------------------------------------------------------
        // 2. CONSTRUCTOR
        // ------------------------------------------------------------------------
        // Sets up mailboxes and initializes starting destination address (e.g. 0x8000_0000)
        function new(mailbox #(dma_transaction) mbx_gen,
                     mailbox #(dma_transaction) mbx_mon,
                     bit [31:0] base_addr = 32'h8000_0000);
            this.mbx_gen        = mbx_gen;
            this.mbx_mon        = mbx_mon;
            this.expected_addr  = base_addr; // Starting address in memory
            this.word_count     = 0;
            this.match_count    = 0;
            this.mismatch_count = 0;
        endfunction


        // ------------------------------------------------------------------------
        // 3. MAIN SCOREBOARD TASK
        // ------------------------------------------------------------------------
        task main();
            // Transaction handles
            dma_transaction exp_trans; // Holds packet from Generator
            dma_transaction act_trans; // Holds packet from Monitor
            bit [31:0]      exp_data;  // Single word popped from queue

            // Run both processes in parallel:
            // Process 1: Collect expected data from Generator
            // Process 2: Compare with actual data from Monitor
            fork

                // ================================================================
                // PROCESS 1: Read from Generator and Store in Queue
                // ================================================================
                forever begin
                    // Wait for Generator to send an expected transaction
                    mbx_gen.get(exp_trans);

                    // Push the expected word into the back of our queue
                    expected_queue.push_back(exp_trans.tdata);
                end

                // ================================================================
                // PROCESS 2: Read from Monitor and Verify Both Testcases!
                // ================================================================
                forever begin
                    // Wait for Monitor to send actual data captured from memory
                    mbx_mon.get(act_trans);

                    // Wait until expected queue has at least one word available
                    wait(expected_queue.size() > 0);

                    // Pop the oldest expected word from the front of the queue
                    exp_data = expected_queue.pop_front();

                    // ------------------------------------------------------------
                    // TESTCASE 1: DATA MATCH VERIFICATION
                    // ------------------------------------------------------------
                    if (act_trans.tdata == exp_data) begin
                        $display("[%0t] [SCB PASS] TESTCASE 1: Data Match! Expected: 0x%08h == Actual: 0x%08h",
                                 $time, exp_data, act_trans.tdata);
                        match_count++; // Increment pass count
                    end else begin
                        $error("[%0t] [SCB FAIL] TESTCASE 1: Data MISMATCH! Expected: 0x%08h != Actual: 0x%08h",
                               $time, exp_data, act_trans.tdata);
                        mismatch_count++; // Increment fail count
                    end

                    // ------------------------------------------------------------
                    // TESTCASE 2: ADDRESS INCREMENT CHECK
                    // Every 4 words (one burst), check if memory address is correct!
                    // ------------------------------------------------------------
                    if (word_count % 4 == 0) begin
                        if (act_trans.addr == expected_addr) begin
                            $display("[%0t] [SCB PASS] TESTCASE 2: Address Match! Burst Address = 0x%08h",
                                     $time, act_trans.addr);
                        end else begin
                            $error("[%0t] [SCB FAIL] TESTCASE 2: Address MISMATCH! Expected: 0x%08h != Actual: 0x%08h",
                                   $time, expected_addr, act_trans.addr);
                        end

                        // After checking this 4-word burst, increment expected address by +16 bytes!
                        expected_addr = expected_addr + 16;
                    end

                    // Increment word counter for the next beat
                    word_count++;

                end

            join_none // Let both processes run independently in background
        endtask


        // ------------------------------------------------------------------------
        // 4. REPORT SUMMARY FUNCTION
        // ------------------------------------------------------------------------
        // Prints final test verdict at the end of simulation
        function void report();
            $display("\n=======================================================");
            $display("                 SCOREBOARD FINAL REPORT               ");
            $display("=======================================================");
            $display(" Total Words Checked: %0d", match_count + mismatch_count);
            $display(" Total Matches (PASS): %0d", match_count);
            $display(" Total Mismatches(FAIL): %0d", mismatch_count);

            if (mismatch_count == 0 && match_count > 0) begin
                $display(" >>> ALL TESTCASES PASSED SUCCESSFULLY! <<<");
            end else begin
                $display(" >>> SOME TESTCASES FAILED! PLEASE CHECK WAVEFORM! <<<");
            end
            $display("=======================================================\n");
        endfunction

    endclass
