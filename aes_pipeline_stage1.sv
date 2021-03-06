module aes_pipeline_stage1 (
    clk,
    i_cipher_key,
    i_plain_text,
    i_aad,
    i_new_instance,
    i_iv,
    i_instance_size,
    i_pt_instance,
    i_id,  // Parallel id 0 1 2 3 for 4 parallel workers
    o_counter,
    o_key_schedule,
    o_plain_text,
    o_aad,
    o_iv,
    o_instance_size,
    o_new_instance,
    o_phase,
    o_pt_instance
);

    input logic           clk;
    input logic [0:127]   i_cipher_key;
    input logic [0:127]   i_plain_text;
    input logic [0:127]   i_aad;
    input logic [0:95]    i_iv;
    input logic [0:3]     i_id;
    input logic [0:127]   i_instance_size;
    input logic           i_new_instance;
    input logic           i_pt_instance;

    output logic [0:127]   o_plain_text;
    output logic [0:127]   o_aad;
    output logic [0:95]    o_iv;
    output logic [0:127]    o_counter;
    output logic [0:127]   o_instance_size;
    output logic           o_new_instance;
    output logic           o_pt_instance;
    output logic [0:1407]  o_key_schedule;
    output logic [0:2]     o_phase;

    logic [0:127]   r_cipher_key;
    logic [0:127]   r_plain_text;
    logic [0:127]   r_aad;
    logic [0:95]    r_iv;
    logic [0:127]   r_instance_size;
    logic           r_new_instance;
    logic           r_pt_instance;
    logic           r_invalid = 0;

    logic [0:127]   r_counter;
    logic [0:127]   w_counter = 128'd100000;
    logic           w_invalid = 1;
    logic [0:3]     r_id;

    /* Helper variables */
    integer aad_blocks;
    integer total_blocks;

    always_ff @(posedge clk)
    begin
        r_cipher_key    <= i_cipher_key;
        r_plain_text    <= i_plain_text;
        r_aad           <= i_aad;
        r_iv            <= i_iv;
        r_id            <= i_id;
        r_instance_size <= i_instance_size;
        r_new_instance  <= i_new_instance;
        r_pt_instance   <= i_pt_instance;

        r_counter       <= w_counter; // Cycle
        r_invalid       <= w_invalid; // Cycle
    end
    
    always_comb
    begin
        // Separte key generation with encryption modules
        //o_key_schedule = fn_key_expansion(r_cipher_key, 1407'b0, 1);

        /* Carrying forward register values for subsequent stages */
        o_plain_text    = r_plain_text;
        o_aad           = r_aad;
        o_iv            = r_iv;
        o_instance_size = r_instance_size;
        o_new_instance  = r_new_instance;
        o_pt_instance   = r_pt_instance;
    end
    
    // Time control logic of state machine
    // Ethernet frame can be no bigger than 100000 * 128 bits
    always_comb
    begin
        if (r_new_instance == 1)
        begin
            w_counter = r_id;
        end
        else if (r_invalid == 1)
        begin
           w_counter = 100000;
        end
        else
        begin
            w_counter = r_counter + 1; // Indicating there are 4 encryption workers
        end

        total_blocks = ((r_instance_size[0:63] + r_instance_size[64:127]) >> 7);
        aad_blocks = r_instance_size[0:63] >> 7;
        o_counter = w_counter;

        if (w_counter == 100000)
        begin
            // Invalid status
            o_phase = 3'b100;
            w_invalid = 1;
        end
        else if (w_counter == total_blocks - 1)
        begin
            // Last text block delivering
            if (total_blocks == aad_blocks + 1)
            begin
                // The first is exactly the last
                o_phase = 3'b111;
            end
            else
            begin
                o_phase = 3'b011;
            end
            w_invalid = 1;
        end
        else if (w_counter > aad_blocks)
        begin
            // Text block (not the last one) delivering
            o_phase = 3'b001;
            w_invalid = 0;
        end
        else if (w_counter == aad_blocks)
        begin
            // Text block (the first one) delivering
            o_phase = 3'b000;
            w_invalid = 0;
        end
        else
        begin
            // AAD delivering (invalid)
            o_phase = 3'b010;
            w_invalid = 0;
        end
    end

endmodule
