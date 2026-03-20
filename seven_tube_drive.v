module seven_tube_drive (
    input  wire       clk,        // 100MHz
    input  wire       rst_n,
    input  wire [6:0] left_num,
    input  wire [6:0] right_num,

    output reg        SI,
    output reg        RCK,
    output reg        SCK,
    output reg        dig_oe_n    // 板上唯一 OE，接 P8
);

    // ----------------------------
    // 1) 分数拆位
    // ----------------------------
    wire [3:0] left_tens;
    wire [3:0] left_ones;
    wire [3:0] right_tens;
    wire [3:0] right_ones;

    assign left_tens  = left_num  / 10;
    assign left_ones  = left_num  % 10;
    assign right_tens = right_num / 10;
    assign right_ones = right_num % 10;

    // ----------------------------
    // 2) 段码
    // 布局从左到右：
    // D8 D7 D6 D5 D4 D3 D2 D1
    // 空 空 左十 左个  -  - 右十 右个
    // ----------------------------
    wire [7:0] seg_d1;
    wire [7:0] seg_d2;
    wire [7:0] seg_d3;
    wire [7:0] seg_d4;
    wire [7:0] seg_d5;
    wire [7:0] seg_d6;
    wire [7:0] seg_d7;
    wire [7:0] seg_d8;

    seg7_cc_encoder u_enc_d1 (.data(right_ones), .seg(seg_d1));
    seg7_cc_encoder u_enc_d2 (.data(right_tens), .seg(seg_d2));
    seg7_cc_encoder u_enc_d3 (.data(4'hA),       .seg(seg_d3)); // '-'
    seg7_cc_encoder u_enc_d4 (.data(4'hA),       .seg(seg_d4)); // '-'
    seg7_cc_encoder u_enc_d5 (.data(left_ones),  .seg(seg_d5));
    seg7_cc_encoder u_enc_d6 (.data(left_tens),  .seg(seg_d6));
    seg7_cc_encoder u_enc_d7 (.data(4'hF),       .seg(seg_d7)); // blank
    seg7_cc_encoder u_enc_d8 (.data(4'hF),       .seg(seg_d8)); // blank

    // ----------------------------
    // 3) 拼成 64 位
    // 和你原来一致：D1 最低字节，D8 最高字节
    // ----------------------------
    wire [63:0] full_data;
    assign full_data = {
        seg_d8, seg_d7, seg_d6, seg_d5,
        seg_d4, seg_d3, seg_d2, seg_d1
    };

    // ----------------------------
    // 4) 慢时钟分频
    // 100MHz -> 大约 24.4kHz（参考陈菲菲）
    // ----------------------------
    reg [11:0] div_cnt;
    reg        slow_clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt   <= 12'd0;
            slow_clk  <= 1'b0;
        end else if (div_cnt == 12'd2047) begin
            div_cnt   <= 12'd0;
            slow_clk  <= ~slow_clk;
        end else begin
            div_cnt   <= div_cnt + 1'b1;
        end
    end

    // ----------------------------
    // 5) 64位串行发送状态机
    // ----------------------------
    localparam S_SHIFT = 1'b0;
    localparam S_LATCH = 1'b1;

    reg        state;
    reg [5:0]  bit_cnt;
    reg        phase;

    always @(posedge slow_clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_SHIFT;
            bit_cnt  <= 6'd0;
            phase    <= 1'b0;
            SI       <= 1'b0;
            SCK      <= 1'b0;
            RCK      <= 1'b0;

            // 先按低有效常开写；如果还不亮，把这里改成 1'b1 再试一次
            dig_oe_n <= 1'b0;
        end else begin
            case (state)
                S_SHIFT: begin
                    RCK <= 1'b0;
                    if (phase == 1'b0) begin
                        SI    <= full_data[bit_cnt];
                        SCK   <= 1'b0;
                        phase <= 1'b1;
                    end else begin
                        SCK   <= 1'b1;
                        phase <= 1'b0;
                        if (bit_cnt == 6'd63) begin
                            state   <= S_LATCH;
                            bit_cnt <= 6'd0;
                        end else begin
                            bit_cnt <= bit_cnt + 1'b1;
                        end
                    end
                end

                S_LATCH: begin
                    SCK <= 1'b0;
                    if (phase == 1'b0) begin
                        RCK   <= 1'b1;
                        phase <= 1'b1;
                    end else begin
                        RCK   <= 1'b0;
                        phase <= 1'b0;
                        state <= S_SHIFT;
                    end
                end
            endcase
        end
    end

endmodule


module seg7_cc_encoder (
    input  wire [3:0] data,
    output reg  [7:0] seg
);
    always @(*) begin
        case (data)
            4'h0: seg = 8'b11111100;
            4'h1: seg = 8'b01100000;
            4'h2: seg = 8'b11011010;
            4'h3: seg = 8'b11110010;
            4'h4: seg = 8'b01100110;
            4'h5: seg = 8'b10110110;
            4'h6: seg = 8'b10111110;
            4'h7: seg = 8'b11100000;
            4'h8: seg = 8'b11111110;
            4'h9: seg = 8'b11110110;
            4'hA: seg = 8'b00000010; // '-'
            4'hF: seg = 8'b00000000; // blank
            default: seg = 8'b00000000;
        endcase
    end
endmodule