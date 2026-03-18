`timescale 1ns/1ps

module tb_pingpong_game;
    reg         clk;
    reg         rst_n;
    reg         kd1;
    reg         kd2;
    wire [7:0]  led;
    wire [6:0]  score1;
    wire [6:0]  score2;
    wire        beep;
    wire SI;
    wire RCK;
    wire SCK;
    wire seg_oe_n;
    wire dig_oe_n;

    localparam integer BALL_STEP_CYCLES = 3;
    localparam integer DEBOUNCE_CYCLES  = 2;
    localparam integer BEEP_CYCLES      = 4;
    localparam integer HOLD_UNIT_CYCLES = 4;

        pingpong_game #(
        .BALL_STEP_CYCLES(BALL_STEP_CYCLES),
        .DEBOUNCE_CYCLES (DEBOUNCE_CYCLES),
        .BEEP_CYCLES     (BEEP_CYCLES),
        .HOLD_UNIT_CYCLES(HOLD_UNIT_CYCLES)
    ) uut (
        .clk      (clk),
        .rst_n    (rst_n),
        .kd1      (kd1),
        .kd2      (kd2),
        .led      (led),
        .score1   (score1),
        .score2   (score2),
        .beep     (beep),
        .SI       (SI),
        .RCK      (RCK),
        .SCK      (SCK),
        .seg_oe_n (seg_oe_n),
        .dig_oe_n (dig_oe_n)
    );

    always #10 clk = ~clk;

    task k1_charge_and_release;
        input integer hold_low_cycles;
        integer i;
        begin
            @(negedge clk);
            kd1 = 1'b0;
            for (i = 0; i < hold_low_cycles; i = i + 1)
                @(negedge clk);
            kd1 = 1'b1;
        end
    endtask

    task k2_charge_and_release;
        input integer hold_low_cycles;
        integer i;
        begin
            @(negedge clk);
            kd2 = 1'b0;
            for (i = 0; i < hold_low_cycles; i = i + 1)
                @(negedge clk);
            kd2 = 1'b1;
        end
    endtask

    task fast_forward_score_pause_end;
        begin
            // 为了避免仿真真正等待 50_000_000 个周期，
            // 在“已经验证暂停期间按键无效”之后，再把暂停计数推到结束前一拍
            @(negedge clk);
            force uut.score_pause_cnt = 32'd49_999_998;
            @(posedge clk);
            release uut.score_pause_cnt;
            repeat (3)@(posedge clk);
        end
    endtask

    initial begin
        clk   = 1'b0;
        rst_n = 1'b0;
        kd1   = 1'b1;
        kd2   = 1'b1;

        #100;
        rst_n = 1'b1;
        #40;

        // 场景1：左侧长按发球，得到较高初速度
        k1_charge_and_release(24);

        // 右侧预先蓄力，在球到最右边时释放，实现回球
        wait (led == 8'b0100_0000);
        @(negedge clk);
        kd2 = 1'b0;
        repeat (12) @(negedge clk);
        wait (led == 8'b1000_0000);
        @(negedge clk);
        kd2 = 1'b1;

        // 场景2：左侧这次蓄力不足，只有当“本步后速度掉到0且仍未过线”时，才判不过线，右侧加1分
        wait (score2 == 7'd0);
        wait (led == 8'b0000_0001);
        @(posedge clk);
        k1_charge_and_release(3);
        wait (score2 == 7'd1);

        // 场景3：失分后的1秒暂停期间，按下然后松开发球无效
        // 先确认处于暂停状态
        @(posedge clk);
        if (uut.running !== 1'b0 || uut.score_pause !== 1'b1) begin
            $display("[FAIL] scene3 setup error: not in pause state, running=%b score_pause=%b",
                     uut.running, uut.score_pause);
            $stop;
        end

        // 暂停期间尝试左侧按下并释放，应该无效
        k1_charge_and_release(10);
        repeat (6) @(posedge clk);

        if (uut.running !== 1'b0) begin
            $display("[FAIL] scene3: serve unexpectedly started during score_pause");
            $stop;
        end
        if (uut.score_pause !== 1'b1) begin
            $display("[FAIL] scene3: score_pause unexpectedly cleared");
            $stop;
        end
        if (led !== 8'b0000_0000) begin
            $display("[FAIL] scene3: LED should remain off during pause, led=%b", led);
            $stop;
        end
        if (score1 !== 7'd0 || score2 !== 7'd1) begin
            $display("[FAIL] scene3: score changed unexpectedly, score1=%0d score2=%0d", score1, score2);
            $stop;
        end

        // 快进到暂停结束
        fast_forward_score_pause_end;
        if (uut.score_pause !== 1'b0) begin
            $display("[FAIL] scene3: score_pause should be released");
            $stop;
        end

        repeat (5) @(posedge clk);
        // 场景4：暂停结束后重新发球，然后不过线，右侧再加1分
        @(posedge clk);
        k1_charge_and_release(3);
        wait (score2 == 7'd2);

        if (score1 !== 7'd0 || score2 !== 7'd2) begin
            $display("[FAIL] scene4: unexpected final score score1=%0d score2=%0d", score1, score2);
            $stop;
        end

        $display("[PASS] all 4 scenes completed.");
        #200;
        $stop;
    end

    initial begin
        $monitor("t=%0t rst_n=%b kd1=%b kd2=%b led=%b score1=%0d score2=%0d beep=%b pos=%0d dir=%b run=%b speed=%0d travel=%0d holdL=%0d holdR=%0d pause=%b pause_cnt=%0d",
                 $time, rst_n, kd1, kd2, led, score1, score2, beep,
                 uut.ball_pos, uut.dir, uut.running, uut.speed_level, uut.travel_count,
                 uut.hold_cycles_left, uut.hold_cycles_right, uut.score_pause, uut.score_pause_cnt);
    end
endmodule
