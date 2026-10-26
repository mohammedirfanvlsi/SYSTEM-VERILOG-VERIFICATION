 // ============================================================================
    // File Name:    dma_generator.sv
    // Project:      AXI DMA Controller Design and Verification
    // Description:  Generates random stream packets and sends them to Driver & Scoreboard
    // ============================================================================

    `timescale 1ns / 1ps

    class dma_generator;

        // ------------------------------------------------------------------------
        // 1. CLASS VARIABLES & HANDLES
        // ------------------------------------------------------------------------

        // Transaction handle to hold the created packet
        dma_transaction trans;

        // Mailbox to send transaction to the DRIVER
        mailbox #(dma_transaction) mbx_drv;

        // Mailbox to send a copy to the SCOREBOARD (for expected data check)
        mailbox #(dma_transaction) mbx_scb;

        // Number of packets we want to generate (e.g. 4 words or 8 words)
        int count;

        // Event to signal the testbench that generation is complete
        event ended;


        // ------------------------------------------------------------------------
        // 2. CONSTRUCTOR (new function)
        // ------------------------------------------------------------------------
        // Connects the mailboxes created in the environment to this generator
        function new(mailbox #(dma_transaction) mbx_drv,
                     mailbox #(dma_transaction) mbx_scb);
            this.mbx_drv = mbx_drv; // Connect Driver mailbox
            this.mbx_scb = mbx_scb; // Connect Scoreboard mailbox
        endfunction


        // ------------------------------------------------------------------------
        // 3. MAIN GENERATION TASK
        // ------------------------------------------------------------------------
        task main();
            // Loop from 1 up to the total count (e.g. 1 to 4)
            for (int i = 1; i <= count; i++) begin

                // Step 1: Create a fresh transaction object
                trans = new();

                // Step 2: Randomize tdata
                if (!trans.randomize()) begin
                    $error("[GENERATOR ERROR] Randomization Failed!");
                end

                // Step 3: Set tlast = 1 ONLY on the final word!
                if (i == count) begin
                    trans.tlast = 1'b1;  // Final word of the packet
                end else begin
                    trans.tlast = 1'b0;  // Normal word
                end

                // Step 4: Print what we generated to the terminal
                trans.display("GENERATOR");

                // Step 5: Put packet into Driver mailbox (to drive into DUT)
                mbx_drv.put(trans);

                // Step 6: Put packet into Scoreboard mailbox (as expected data)
                mbx_scb.put(trans);

            end // end of for loop

            // Trigger the "ended" event to notify testbench that generator is done
            -> ended;

        endtask : main

    endclass : dma_generator
