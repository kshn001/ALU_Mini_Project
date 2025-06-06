`include "alu_verified_design.v"
`define PASS 1'b1
`define FAIL 1'b0
`define no_of_testcase 90// Adjust based on stimulus count

module test_bench_alu #(parameter WIDTH = 8, parameter CMD_WIDTH = 4)();

    localparam TESTCASE_WIDTH  = 19 + 2*WIDTH + (2*WIDTH +1) + CMD_WIDTH;
    localparam RESPONSE_WIDTH  = TESTCASE_WIDTH + 6 + (2*WIDTH + 1);
    localparam RESULT_WIDTH    = (2*WIDTH + 1) + 6;
    localparam SCB_WIDTH       = (6 + WIDTH + 1) + WIDTH + 8 + (6 + 2*WIDTH + 1);

    reg [TESTCASE_WIDTH-1:0] curr_test_case = 0;
    reg [TESTCASE_WIDTH-1:0] stimulus_mem [0:`no_of_testcase-1];
    reg [RESPONSE_WIDTH-1:0] response_packet;

    integer i, j;
    event fetch_stimulus;

    reg CLK, RST, CE;
    reg [WIDTH-1:0] OPA, OPB;
    reg [CMD_WIDTH-1:0] CMD;
    reg MODE, CIN;
    reg [7:0] Feature_ID;
    reg [2:0] Comparison_EGL;
    reg [WIDTH:0] Expected_RES;
    reg [WIDTH-1:0] Reserved_RES;
    reg err, cout, ov;
    reg [1:0] INP_VALID;

    wire [2*WIDTH:0] RES;
    wire ERR, OFLOW, COUT;
    wire [2:0] EGL;
    wire [RESULT_WIDTH-1:0] expected_data;
    reg  [RESULT_WIDTH-1:0] exact_data;

    ALU #(.opwidth(WIDTH), .cmdwidth(CMD_WIDTH)) inst_dut (
        .clk(CLK), .rst(RST), .opa(OPA), .opb(OPB), .cmd(CMD), .m(MODE),
        .ce(CE), .cin(CIN), .inp_valid(INP_VALID),
        .res(RES), .err(ERR), .oflow(OFLOW), .cout(COUT),
        .g(EGL[1]), .l(EGL[0]), .e(EGL[2])
    );

    integer stim_mem_ptr = 0, stim_stimulus_mem_ptr = 0;
integer fid =0 , pointer =0 ;

  task read_stimulus(); begin
    #10 $readmemb("stimulus.txt", stimulus_mem);
  end endtask

  always @(fetch_stimulus) begin
    curr_test_case = stimulus_mem[stim_mem_ptr];
    $display ("Stimulus data = %0b", stimulus_mem[stim_mem_ptr]);
    stim_mem_ptr = stim_mem_ptr + 1;
  end

  initial begin CLK = 0; forever #60 CLK = ~CLK; end

  task automatic driver();
    begin
      ->fetch_stimulus;
      @(posedge CLK);
      Feature_ID = curr_test_case[(TESTCASE_WIDTH-1)-: 8];
      INP_VALID = curr_test_case[(TESTCASE_WIDTH-9) -: 2];
      OPA = curr_test_case[(TESTCASE_WIDTH - 11) -: WIDTH ];
      OPB = curr_test_case[(TESTCASE_WIDTH - 11 - WIDTH)-: WIDTH];
      CMD = curr_test_case[(TESTCASE_WIDTH - 11 - 2*WIDTH) -:4];//21:18
      CIN = curr_test_case[(TESTCASE_WIDTH - 11 - 2*WIDTH - CMD_WIDTH)];//17
      CE = curr_test_case[(TESTCASE_WIDTH - 11 - 2*WIDTH - CMD_WIDTH-1)];//16
      MODE = curr_test_case[(TESTCASE_WIDTH - 11 - 2*WIDTH - CMD_WIDTH-2)];//15
      Reserved_RES = curr_test_case[(TESTCASE_WIDTH - 11 - 2*WIDTH - CMD_WIDTH-3)-:WIDTH];
      Expected_RES = curr_test_case[(TESTCASE_WIDTH - 11 - 2*WIDTH - CMD_WIDTH-3-WIDTH)-: WIDTH+1];
      cout = curr_test_case[5];
      Comparison_EGL = curr_test_case[4:2];//3bit_EGL
      ov = curr_test_case[1];//1_ERR
      err = curr_test_case[0];//0_OV
      $display("Driving: Feature_ID=%8b, INP_VALID=%2b, OPA=%b, OPB=%b, CMD=%b, CIN=%b, CE=%b, MODE=%b, Reserved_RES=%b, expected_result=%b, COUT=%b, comparision_EGL=%3b, OV=%b, ERR=%b",
               Feature_ID,INP_VALID, OPA, OPB, CMD,CIN,CE,MODE,Reserved_RES,Expected_RES,cout,Comparison_EGL,ov,err);
    end
  endtask



  task dut_reset(); begin
    CE = 1;
    #10 RST = 1;
    #20 RST = 0;
  end endtask
  task global_init();
    begin
        curr_test_case = {TESTCASE_WIDTH{1'b0}};
        response_packet = {(TESTCASE_WIDTH + 6 +(2*WIDTH+1)){1'b0}};
        stim_mem_ptr = 0;
    end
  endtask

  task monitor(); begin
    repeat(5) @(posedge CLK);
    #5 begin
      response_packet[TESTCASE_WIDTH-1:0] = curr_test_case;
      response_packet[TESTCASE_WIDTH +: 5] = {ERR, OFLOW, EGL, COUT};
      response_packet[TESTCASE_WIDTH+5 +: WIDTH+1] = RES;
      exact_data = {RES, COUT, EGL, OFLOW, ERR};
      $display("Monitor: RES=%b, COUT=%b, EGL=%b, OFLOW=%b, ERR=%b",
               RES, COUT, EGL, OFLOW, ERR);
    end
  end endtask

  assign expected_data = {Reserved_RES,Expected_RES, cout, Comparison_EGL, ov, err};

  reg [SCB_WIDTH-1:0] scb_stimulus_mem [0:`no_of_testcase-1];

  task score_board();
    reg[6+WIDTH :0]expected_res;
    reg[WIDTH-1:0]Reserved_RES;
    reg[7:0]feature_id;
    reg[6+2*WIDTH :0]response_data;
    begin
      #5;
      feature_id = curr_test_case[(TESTCASE_WIDTH -1) -:8];
      Reserved_RES = curr_test_case[(TESTCASE_WIDTH - 11 - 2*WIDTH - CMD_WIDTH-3)-:WIDTH];
      expected_res = curr_test_case[(TESTCASE_WIDTH - 11 - 2*WIDTH - CMD_WIDTH-3-WIDTH)-: WIDTH+1];
      response_data = response_packet[TESTCASE_WIDTH +:(2*WIDTH+7)];
      $display("expected result = %b ,response data = %b",expected_data,exact_data);
      if(expected_data === exact_data) begin
        scb_stimulus_mem[stim_stimulus_mem_ptr] = {1'b0, Feature_ID,
          expected_data, response_data, 1'b0, `PASS};
        $display("Test %0d PASSED", stim_stimulus_mem_ptr);
      end
      else begin
        scb_stimulus_mem[stim_stimulus_mem_ptr] = {1'b0, Feature_ID,
          expected_data, response_data, 1'b0, `FAIL};
        $display("Test %0d FAILED", stim_stimulus_mem_ptr);
      end
      stim_stimulus_mem_ptr = stim_stimulus_mem_ptr + 1;
    end
  endtask

task gen_report;
    integer file_id, pointer, i;  // Declare loop variable outside
    begin
      file_id = $fopen("results.txt", "w");
      pointer = 0;  // Initialize counter
      while (pointer < `no_of_testcase) begin  // Changed to while loop
        $fdisplay(file_id, "Feature ID %8b : %s",
                 scb_stimulus_mem[pointer][SCB_WIDTH-2 -: 8],
                 scb_stimulus_mem[pointer][0] ? "PASS" : "FAIL");
        pointer = pointer + 1;  // Changed from ++
      end
      $fclose(file_id);
    end
  endtask

  initial begin
    #10;
    $display("\n--- Starting ALU Verification ---");
    global_init();
    dut_reset();
    read_stimulus();
    for(j = 0; j <= `no_of_testcase-1; j = j + 1) begin
      fork
        driver();
        monitor();
      join
      score_board();
    end
    gen_report();
    $fclose(fid);
    #100 $display("\n--- Verification Complete ---");
    $finish();
  end
endmodule
