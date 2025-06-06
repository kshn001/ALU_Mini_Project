`include "define.v"

module ALU #(parameter WIDTH = 8  )( OPA, OPB, CIN, CLK, RST, CE, MODE, INP_VALID, CMD, RES, OFLOW, COUT, G, L, E, ERR );
    input  wire [WIDTH-1:0] OPA;
    input  wire [WIDTH-1:0] OPB;
    input  wire CIN;
    input  wire CLK;
    input  wire RST;
    input  wire CE;
    input  wire MODE;
    input  wire [1:0] INP_VALID;
    input  wire [3:0] CMD;

   // output reg  [2*WIDTH-1:0] RES,
   // output reg [2*WIDTH:0]RES_MUL,
    output reg  OFLOW;
    output reg  COUT;
    output reg  G;
    output reg  L;
    output reg  E;
    output reg  ERR;

    `define MUL 0

    `ifdef MUL
      output reg  [2*WIDTH-1:0] RES;
    `else
      output reg  [WIDTH:0] RES;
    `endif



    
    localparam ROTATE_WIDTH = $clog2(WIDTH);
    wire [ROTATE_WIDTH-1:0] rotate_amt = OPB[ROTATE_WIDTH-1:0];
    wire invalid_rotate = |OPB[WIDTH-1:ROTATE_WIDTH+1];

    reg signed [WIDTH-1:0] signed_A, signed_B;
    reg [2*WIDTH-1:0] RES_t;
    reg OFLOW_t, COUT_t, G_t, L_t, E_t, ERR_t;

    // Pipelining for multiplication (3-cycle delay)
    reg mult_pending;                // Stage 1 control
    reg [3:0] mult_cmd;
    reg [WIDTH-1:0] latched_OPA, latched_OPB;

    reg [2*WIDTH-1:0] mult_res_t;    // Stage 2 value
    reg mult_valid_stage2;          // Stage 2 flag

    
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            RES   <= 0; COUT <= 0; OFLOW <= 0;
            G <= 0; L <= 0; E <= 0; ERR <= 0;

            RES_t <= 0; COUT_t <= 0; OFLOW_t <= 0;
            G_t <= 0; L_t <= 0; E_t <= 0; ERR_t <= 0;

            mult_pending <= 0;
            mult_valid_stage2 <= 0;
            mult_res_t <= 0;
            mult_cmd <= 0;
            latched_OPA <= 0;
            latched_OPB <= 0;
        end

        else if (CE) begin
            
            if (INP_VALID == 2'b11 && MODE == 1'b1 && (CMD == `MUL_INC || CMD == `MUL_SHIFT)) begin
                mult_cmd <= CMD;
                latched_OPA <= OPA;
                latched_OPB <= OPB;
                mult_pending <= 1;
            end else begin
                mult_pending <= 0;
            end

            //  computing multiplication result
            if (mult_pending) begin
                case (mult_cmd)
                    `MUL_INC:   mult_res_t <= (latched_OPA + 1) * (latched_OPB + 1);
                    `MUL_SHIFT: mult_res_t <= (latched_OPA << 1) * latched_OPB;
                    default:    mult_res_t <= 0;
                endcase
                mult_valid_stage2 <= 1;
            end else begin
                mult_valid_stage2 <= 0;
            end

            // Combinational logic for other operations
            RES_t = 0; COUT_t = 0; OFLOW_t = 0;
            G_t = 0; L_t = 0; E_t = 0; ERR_t = 0;

            if (INP_VALID == 2'b11 || INP_VALID == 2'b01 || INP_VALID == 2'b10) begin
                case (MODE)
                    1'b1: begin // Arithmetic Mode
                        if (INP_VALID == 2'b11) begin
                            case (CMD)
                                `ADD:      begin RES_t = OPA + OPB; COUT_t = RES_t[WIDTH]; end
                                `SUB:      begin RES_t = OPA - OPB; OFLOW_t = (OPA < OPB); end
                                `ADD_CIN:  begin RES_t = OPA + OPB + CIN; COUT_t = RES_t[WIDTH]; end
                                `SUB_CIN:  begin RES_t = OPA - OPB - CIN; OFLOW_t = (OPA < OPB); end
                                `CMP:      begin G_t = (OPA > OPB); L_t = (OPA < OPB); E_t = (OPA == OPB); end
                                `S_ADD:    begin
                                    signed_A = $signed(OPA); signed_B = $signed(OPB);
                                    RES_t = signed_A + signed_B + CIN;
                                    COUT_t = RES_t[WIDTH];
                                    OFLOW_t = (signed_A[WIDTH-1] == signed_B[WIDTH-1]) &&
                                              (RES_t[WIDTH-1] != signed_A[WIDTH-1]);
                                    G_t = (signed_A > signed_B);
                                    L_t = (signed_A < signed_B);
                                    E_t = (signed_A == signed_B);
                                end
                                `S_SUB: begin
                                    signed_A = $signed(OPA); signed_B = $signed(OPB);
                                    RES_t = signed_A - signed_B - CIN;
                                    OFLOW_t = (signed_A[WIDTH-1] != signed_B[WIDTH-1]) &&
                                              (RES_t[WIDTH-1] != signed_A[WIDTH-1]);
                                    G_t = (signed_A > signed_B);
                                    L_t = (signed_A < signed_B);
                                    E_t = (signed_A == signed_B);
                                end
                                default: begin RES_t = 0; ERR_t = 1; end
                            endcase
                        end else if (INP_VALID == 2'b01) begin
                            case (CMD)
                                `INC_A: RES_t = OPA + 1;
                                `DEC_A: RES_t = OPA - 1;
                                default: begin RES_t = 0; ERR_t = 1; end
                            endcase
                        end else if (INP_VALID == 2'b10) begin
                            case (CMD)
                                `INC_B: RES_t = OPB + 1;
                                `DEC_B: RES_t = OPB - 1;
                                default: begin RES_t = 0; ERR_t = 1; end
                            endcase
                        end
                    end

                    1'b0: begin // Logical Mode
                        if (INP_VALID == 2'b11) begin
                            case (CMD)
                                `AND:    RES_t = OPA & OPB;
                                `NAND:   RES_t = ~(OPA & OPB);
                                `OR:     RES_t = OPA | OPB;
                                `NOR:    RES_t = ~(OPA | OPB);
                                `XOR:    RES_t = OPA ^ OPB;
                                `XNOR:   RES_t = ~(OPA ^ OPB);
                                `ROL_A_B: begin
                                    if (invalid_rotate) ERR_t = 1;
                                    else RES_t = (OPA << rotate_amt) | (OPA >> (WIDTH - rotate_amt));
                                end
                                `ROR_A_B: begin
                                    if (invalid_rotate) ERR_t = 1;
                                    else RES_t = (OPA >> rotate_amt) | (OPA << (WIDTH - rotate_amt));
                                end
                                default: begin RES_t = 0; ERR_t = 1; end
                            endcase
                        end else if (INP_VALID == 2'b01) begin
                            case (CMD)
                                `NOT_A:  RES_t = ~OPA;
                                `SHL1_A: RES_t = OPA << 1;
                                `SHR1_A: RES_t = OPA >> 1;
                                default: begin RES_t = 0; ERR_t = 1; end
                            endcase
                        end else if (INP_VALID == 2'b10) begin
                            case (CMD)
                                `NOT_B:  RES_t = ~OPB;
                                `SHL1_B: RES_t = OPB << 1;
                                `SHR1_B: RES_t = OPB >> 1;
                                default: begin RES_t = 0; ERR_t = 1; end
                            endcase
                        end
                    end
                    default: begin RES_t = 0; ERR_t = 1; end
                endcase
            end
        end
    end

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            RES <= 0; COUT <= 0; OFLOW <= 0;
            G <= 0; L <= 0; E <= 0; ERR <= 0;
        end
        else if (mult_valid_stage2) begin
            RES <= mult_res_t;
            COUT <= 0; OFLOW <= 0; G <= 0; L <= 0; E <= 0; ERR <= 0;
        end
        else if (CE) begin
            RES   <= RES_t;
            COUT  <= COUT_t;
            OFLOW <= OFLOW_t;
            G     <= G_t;
            L     <= L_t;
            E     <= E_t;
            ERR   <= ERR_t;
        end
    end

endmodule
