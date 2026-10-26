
    // ============================================================================
    // File Name:    dma_coverage.sv
    // Project:      AXI DMA Controller Design and Verification
    // Description:  Measures functional coverage using Mailbox directly from Monitor
    // ============================================================================

    `timescale 1ns / 1ps

    class dma_coverage;

        // ------------------------------------------------------------------------
        // 1. MAILBOX & TRANSACTION HANDLE
        // ------------------------------------------------------------------------

        // Mailbox handle to receive captured transactions from Monitor
        mailbox #(dma_transaction) mbx_cov;

        // Transaction handle to hold incoming packet from the mailbox
        dma_transaction trans;


        // ------------------------------------------------------------------------
        // 2. COVERGROUP DEFINITION
        // ------------------------------------------------------------------------
        // Tracks the fields directly from the transaction!
        covergroup cg_dma;

            // Coverpoint 1: Did we test both normal beats (0) AND the final beat (1)?
            cp_tlast: coverpoint trans.tlast {
                bins normal_beat = {0}; // Words in the middle of a burst
                bins last_beat   = {1}; // Final word of the packet (TLAST=1)
            }

            // Coverpoint 2: Address Increment Check (Testcase 2!)
            // Did we hit the starting address and increment by +16 bytes?
            cp_addr: coverpoint trans.addr {
                bins start_addr   = {32'h8000_0000};                   // Burst 1 starting address
                bins second_burst = {32'h8000_0010};                   // Burst 2 address (+16 bytes)
                bins other_bursts = {[32'h8000_0020 : 32'h8000_00F0]}; // Further bursts
            }

        endgroup


        // ------------------------------------------------------------------------
        // 3. CONSTRUCTOR
        // ------------------------------------------------------------------------
        // Connects the mailbox from the environment and instantiates the covergroup
        function new(mailbox #(dma_transaction) mbx_cov);
            this.mbx_cov = mbx_cov; // Connect the mailbox from Monitor
            cg_dma       = new();   // Instantiate the covergroup
        endfunction


        // ------------------------------------------------------------------------
        // 4. MAIN TASK (Runs continuously, listening to the Mailbox)
        // ------------------------------------------------------------------------
        task main();
            forever begin

                // Step 1: Wait until Monitor drops a transaction into the mailbox
                mbx_cov.get(trans);

                // Step 2: Sample the covergroup right here inside the class!
                cg_dma.sample();

            end
        endtask


        // ------------------------------------------------------------------------
        // 5. REPORT COVERAGE FUNCTION
        // ------------------------------------------------------------------------
        // Prints the final coverage score at the end of simulation
        function void display_coverage();
            $display("\n=======================================================");
            $display("               FUNCTIONAL COVERAGE REPORT             ");
            $display("=======================================================");
    $display(" Total Functional Coverage: %0.2f %%", cg_dma.get_inst_coverage());            $display("=======================================================\n");
        endfunction

    endclass
