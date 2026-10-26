// ============================================================================
    // File Name:    dma_transaction.sv
    // Project:      AXI DMA Controller Design and Verification
    // Description:  Simple transaction class representing one stream data word
    // ============================================================================

    `timescale 1ns / 1ps

    class dma_transaction;

        // ------------------------------------------------------------------------
        // 1. SIGNAL DECLARATIONS
        // ------------------------------------------------------------------------

        // "rand" means randomize will give a random 32-bit value for tdata
        rand bit [31:0] tdata;  // The actual 32-bit data to send into DMA

        // "tlast" is NOT rand because we manually set it to 1 only on the last word!
        bit             tlast;  // 1 = last word of transfer, 0 = normal word
      
                bit [31:0]      addr;   // Destination memory address (for Testcase 2 check!)


        // ------------------------------------------------------------------------
        // 2. CONSTRAINT
        // ------------------------------------------------------------------------

        // Keep tdata non-zero so we don't accidentally send all zeros
        constraint c_tdata {
            tdata != 32'h0000_0000;
        }


        // ------------------------------------------------------------------------
        // 3. DISPLAY METHOD
        // ------------------------------------------------------------------------

        // Prints the transaction data to the simulation terminal
       function void display(string name = "TRANSACTION");
            $display("[%0t] [%s] tdata = 0x%08h | tlast = %0b | addr = 0x%08h",
                     $time, name, tdata, tlast, addr);
        endfunction

    endclass : dma_transaction
