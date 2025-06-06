module ALU #(parameter opwidth = 8 , cmdwidth = 4)(
    input clk,
    input rst,
    input [opwidth-1:0] opa,
    input [opwidth-1:0] opb,
    input [cmdwidth-1:0] cmd,
    input m, ce, cin,
    input [1:0] inp_valid,
    output reg [2*opwidth-1:0] res,
    output reg err, oflow, cout, g, l, e);

    reg [opwidth-1:0] opa_reg, opb_reg;
    reg [cmdwidth-1:0] cmd_reg;
    reg m_reg, cin_reg;
    reg [1:0] inp_valid_reg;
    reg [2*opwidth-1:0] res_temp;
   // reg [1:0] delay1;

   localparam ROTBITS = $clog2(opwidth);



    // FSM Counter and internal regs for cmd 9
    reg [1:0] cmd9_counter;
    reg cmd9_done;

   // reg [opwidth-1:0] opa9, opb9;
   // reg [2*opwidth-1:0] res9_temp;

   /* always @(posedge clk or posedge rst) begin
      if (rst) begin
        cmd9_counter <= 0;
        opa9 <= 0;
        opb9 <= 0;
        res9_temp <= 0;
      end
      else if (ce && m_reg && cmd_reg == 4'd9 && inp_valid_reg == 2'b11) begin
        cmd9_counter <= 2'd1; // Start the 3-cycle FSM
        opa9 <= opa_reg;
        opb9 <= opb_reg;
      end
      else if (cmd9_counter == 2'd1) begin
        res9_temp <= (opa9 + 1) * (opb9 + 1);
        cmd9_counter <= 2'd2;
      end
      else if (cmd9_counter == 2'd2) begin
        res <= res9_temp;
        cmd9_counter <= 0; // Reset FSM
      end
    end*/
    always @(posedge clk or posedge rst) begin
    if (rst) begin
        cmd9_counter <= 0;
        cmd9_done <= 0;
    end else if (cmd == 9) begin
        case (cmd9_counter)
            0: begin
                // first cycle
                cmd9_counter <= 1;
            end
            1: begin
                // second cycle
                cmd9_counter <= 2;
            end
            2: begin
                res_temp <= ((opa+1) * (opb+1));
                cmd9_counter <= 0;
                cmd9_done <= 1;
            end
        endcase
        end else begin
            cmd9_done <= 0; // clear the done flag for non-cmd9 ops
        end
    end
    // Stage 1: Register the inputs
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            opa_reg <= 0;
            opb_reg <= 0;
            cmd_reg <= 0;
            m_reg <= 0;
            cin_reg <= 0;
            inp_valid_reg <= 0;
        end else if (ce) begin
            opa_reg <= opa;
            opb_reg <= opb;
            cmd_reg <= cmd;
            m_reg <= m;
            cin_reg <= cin;
            inp_valid_reg <= inp_valid;
        end
    end
    // Stage 2: Combinational logic based on registered inputs
    always @(*) begin
        res_temp = 0;
        err = 0;
        oflow = 0;
        cout = 0;
        g = 0;
        l = 0;
        e = 0;
        if (m_reg) begin // Arithmetic Mode
            case (cmd_reg)
                'd0:begin
                     if(inp_valid_reg == 2'b11)
                        res_temp = opa_reg + opb_reg;
                     else
                        err =1'b1;
                    end
                'd1:begin
                     if(inp_valid_reg == 2'b11)
                        res_temp = opa_reg - opb_reg;
                     else
                        err =1'b1;
                    end

                'd2:begin
                      if(inp_valid_reg == 2'b11)begin
                        res_temp = opa_reg + opb_reg + cin_reg;
                        cout = res_temp[opwidth];
                      end
                      else
                        err = 1'b1;
                      end
                'd3:begin
                      if(inp_valid_reg == 2'b11)begin
                        res_temp = opa_reg - opb_reg - cin_reg;
                        cout = res_temp[opwidth];
                        end
                      else
                        err = 1'b1;
                    end

                'd4:begin
                      if(inp_valid_reg == 2'b01)
                        res_temp = opa_reg + 1;
                      else
                        err = 1'b1;
                    end
                'd5:begin
                     if(inp_valid_reg == 2'b01)
                        res_temp = opa_reg - 1;
                     else
                        err =1'b1;
                    end
                'd6: begin
                      if(inp_valid_reg == 2'b10)
                        res_temp = opb_reg + 1;
                      else
                        err =1'b1;
                     end

                'd7:begin
                     if(inp_valid_reg == 2'b10)
                        res_temp = opb_reg - 1;
                     else
                        err =1'b1;
                    end
                'd8:begin
                     if(inp_valid_reg == 2'b11) begin
                        if (opa_reg > opb_reg) begin
                            g = 1; l = 0; e = 0;
                        end else if (opa_reg < opb_reg) begin
                            g = 0; l = 1; e = 0;
                        end else begin
                            g = 0; l = 0; e = 1;
                        end
                     end
                     else
                        err =1'b1;

                    end
                /*'d9: begin
                      if (inp_valid_reg == 2'b11) begin
                         if (delay1 >= 2) begin
                          res_temp = (opa_reg + 1) * (opb_reg + 1);
                          delay1 = 0;
                         end else begin
                          delay1 = delay1 + 1;
                          res_temp = 0;
                         end
                      end
                    end*/
                'd9: begin
                    // handled separately via counter FSM
                 end
                'd10:begin
                      if(inp_valid_reg == 2'b11)
                        res_temp = (opa_reg >> 1) * opb_reg;
                      else
                        err =1'b1;
                     end
                'd11:begin
                     if (inp_valid_reg == 2'b11) begin
                            res_temp = $signed (opa_reg) + $signed (opb_reg);
                            cout = res_temp[opwidth];
                            // Overflow (for signed addition)
                            oflow = (opa_reg[opwidth-1] == opb_reg[opwidth-1])&&(res_temp[opwidth-1] != opa_reg[opwidth-1]);
                        if (opa_reg > opb_reg) begin
                            g = 1; l = 0; e = 0;
                        end else if (opa_reg < opb_reg) begin
                            g = 0; l = 1; e = 0;
                        end else begin
                            g = 0; l = 0; e = 1;
                        end
                      end
                      else
                        err = 1'b1;
                      end
                'd12:begin
                       if (inp_valid_reg == 2'b11) begin
                        res_temp = opa_reg - opb_reg;
                        cout = res_temp[opwidth];
                        // Overflow (for signed subtraction)
                        oflow = (opa_reg[opwidth-1] != opb_reg[opwidth-1]) && (res_temp[opwidth-1] != opa_reg[opwidth-1]);
                       if (opa_reg > opb_reg) begin
                            g = 1; l = 0; e = 0;
                       end else if (opa_reg < opb_reg) begin
                            g = 0; l = 1; e = 0;
                       end else begin
                            g = 0; l = 0; e = 1;
                       end
                      end
                      else
                        err = 1'b1;
                     end
                default: res_temp = 0;
            endcase
        end else begin // Logic Mode
            case (cmd_reg)
                4'd0: if(inp_valid_reg == 2'b11) res_temp = opa_reg & opb_reg; else err = 1'b1;
                4'd1: if(inp_valid_reg == 2'b11) res_temp = ~(opa_reg & opb_reg); else err = 1'b1;
                4'd2: if(inp_valid_reg == 2'b11) res_temp = opa_reg | opb_reg; else err = 1'b1;
                4'd3: if(inp_valid_reg == 2'b11) res_temp = ~(opa_reg | opb_reg); else err = 1'b1;
                4'd4: if(inp_valid_reg == 2'b11) res_temp = opa_reg ^ opb_reg; else err = 1'b1;
                4'd5: if(inp_valid_reg == 2'b11) res_temp = ~(opa_reg ^ opb_reg); else err = 1'b1;
                4'd6: if(inp_valid_reg == 2'b01) res_temp = ~opa_reg; else err = 1'b1;
                4'd7: if(inp_valid_reg == 2'b10) res_temp = ~opb_reg; else err = 1'b1;
                4'd8: if(inp_valid_reg == 2'b01) res_temp = opa_reg << 1; else err = 1'b1;
                4'd9: if(inp_valid_reg == 2'b01) res_temp = opa_reg >> 1; else err = 1'b1;
                4'd10: if(inp_valid_reg == 2'b10) res_temp = opb_reg << 1; else err = 1'b1;
                4'd11: if(inp_valid_reg == 2'b10) res_temp = opb_reg >> 1; else err = 1'b1;
                4'd12: if (inp_valid_reg == 2'b01) begin  // ROL_A_B
                        if (opb_reg[opwidth-1:4] != 0)
                            err = 1;
                        else begin
                        // Rotate Left
                        res_temp = (opa_reg << opb_reg[ROTBITS-1:0])|(opa_reg >> (opwidth - opb_reg[ROTBITS-1:0]));
                       end
                      end
                        else err = 1'b1;
                4'd13: if (inp_valid_reg == 2'b01) begin  // ROR_A_B
                        if (opb_reg[opwidth-1:4] != 0)
                        err = 1;
                       else begin
                        // Rotate Right
                        res_temp = (opa_reg >> opb_reg[ROTBITS-1:0])|(opa_reg << (opwidth - opb_reg[ROTBITS-1:0]));
                       end
                      end
                       else err = 1'b1;
                default: res_temp = 0;
            endcase
        end
    end
    // Stage 3: Register the result after one clock cycle
        always @(posedge clk or posedge rst) begin
            if (rst)
                res <= 0;
            else if (ce || cmd9_done)
                 res <= res_temp;
        end
endmodule
