`timescale 1ns/1ps

module tb_pingpong_game_four_cases;
    reg clk;
    reg rst_n;
    reg kd1;
    reg kd2;

    wire [7:0] led;
    wire [6:0] score1;
    wire [6:0] score2;
    wire beep;
    wire SI;
    wire RCK;
    wire SCK;
    wire seg_oe_n;
    wire dig_oe_n;

    // 100MHz
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // 缩小参数便于仿真
    pingpong_game #(
        .BALL_STEP_CYCLES(20),
        .DEBOUNCE_CYCLES(3),
        .BEEP_CYCLES(20),
        .HOLD_UNIT_CYCLES(8),
        .SPEED_LEVEL_MAX(7),
        .MIN_CROSS_COUNT(2)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .kd1(kd1),
        .kd2(kd2),
        .led(led),
        .score1(score1),
        .score2(score2),
        .beep(beep),
        .SI(SI),
        .RCK(RCK),
        .SCK(SCK),
        .seg_oe_n(seg_oe_n),
        .dig_oe_n(dig_oe_n)
    );

    // 观察内部状态
    wire running      = uut.running;
    wire dir          = uut.dir;
    wire [2:0] ball_pos = uut.ball_pos;
    wire flag_left    = uut.flag_left;
    wire flag_right   = uut.flag_right;
    wire score_pause  = uut.score_pause;
    wire [31:0] hold_cycles_left  = uut.hold_cycles_left;
    wire [31:0] hold_cycles_right = uut.hold_cycles_right;

    integer fail_count;

    task expect;
        input cond;
        input [255:0] msg;
        begin
            if (!cond) begin
                fail_count = fail_count + 1;
                $display("[FAIL t=%0t] %0s", $time, msg);
            end else begin
                $display("[PASS t=%0t] %0s", $time, msg);
            end
        end
    endtask

    task press_left_and_release;
        input integer hold_cycles;
        integer i;
        begin
            @(negedge clk);
            kd1 = 1'b0;
            for (i = 0; i < hold_cycles; i = i + 1)
                @(negedge clk);
            kd1 = 1'b1;
        end
    endtask

    task press_right_and_release;
        input integer hold_cycles;
        integer i;
        begin
            @(negedge clk);
            kd2 = 1'b0;
            for (i = 0; i < hold_cycles; i = i + 1)
                @(negedge clk);
            kd2 = 1'b1;
        end
    endtask

    task hold_left_down;
        begin
            @(negedge clk);
            kd1 = 1'b0;
        end
    endtask

    task release_left;
        begin
            @(negedge clk);
            kd1 = 1'b1;
        end
    endtask

    task hold_right_down;
        begin
            @(negedge clk);
            kd2 = 1'b0;
        end
    endtask

    task release_right;
        begin
            @(negedge clk);
            kd2 = 1'b1;
        end
    endtask

    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    task wait_game_idle_and_pause_clear;
        begin
            wait (running == 1'b0);
            wait (score_pause == 1'b0);
            wait_cycles(5);
        end
    endtask

    initial begin
        fail_count = 0;
        rst_n = 1'b0;
        kd1   = 1'b1;
        kd2   = 1'b1;

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        wait_cycles(10);

        // ============================================================
        // 场景1：kd1按下发球，kd2正常按下并回球
        // 为了进入下一场景，随后让左侧不接球，令右侧得分结束本局
        // ============================================================
        $display("\n==== CASE1: kd1 serve, kd2 normal return ====");
        press_left_and_release(12);

        wait (running == 1'b1);
        expect(dir == 1'b1, "CASE1 serve direction is to the right");
        expect(ball_pos == 3'd0, "CASE1 ball starts from left edge");

        wait (ball_pos == 3'd5 && dir == 1'b1 && running == 1'b1);
        hold_right_down();
        $display("[INFO t=%0t] CASE1 kd2 pressed while ball approaching right edge", $time);

        wait (ball_pos == 3'd7 && dir == 1'b1 && running == 1'b1);
        release_right();
        $display("[INFO t=%0t] CASE1 kd2 released at right edge", $time);

        wait (dir == 1'b0 || running == 1'b0);
        expect(running == 1'b1 && dir == 1'b0 && ball_pos == 3'd6,
               "CASE1 kd2 returns the ball successfully");

        // 左侧不接球，等待本局结束
        wait (score2 == 7'd1);
        expect(running == 1'b0, "CASE1 game stops after left misses returned ball");
        expect(score_pause == 1'b1, "CASE1 enters pause after scoring");
        expect(score1 == 7'd0 && score2 == 7'd1, "CASE1 score becomes 0:1");

        // ============================================================
        // 场景2：kd2发球，kd1按下时间过短，回球后因力度不足不过线
        // ============================================================
        wait_game_idle_and_pause_clear();
        $display("\n==== CASE2: kd2 serve, kd1 too short press, ball does not cross ====");

        press_right_and_release(12);
        wait (running == 1'b1 && dir == 1'b0);
        expect(ball_pos == 3'd7, "CASE2 ball starts from right edge");

        // 左侧到边线时，短按后立刻松开，形成最低速回球
        wait (ball_pos == 3'd0 && dir == 1'b0 && running == 1'b1);
        press_left_and_release(3);
        $display("[INFO t=%0t] CASE2 kd1 released quickly at left edge", $time);

        wait (score2 == 7'd2);
        expect(running == 1'b0, "CASE2 game stops after weak return fails to cross");
        expect(score_pause == 1'b1, "CASE2 enters pause after scoring");
        expect(score1 == 7'd0 && score2 == 7'd2, "CASE2 score becomes 0:2");

        // ============================================================
        // 场景3：场景2结束后的暂停周期内，kd1再次按下，无效
        // ============================================================
        $display("\n==== CASE3: during pause after CASE2, kd1 press is invalid ====");
        expect(score_pause == 1'b1, "CASE3 starts during score pause");

        fork
            begin : case3_press_during_pause
                press_left_and_release(12);
            end
            begin : case3_watch_invalid
                integer saw_flag_during_pause;
                saw_flag_during_pause = 0;
                repeat (30) begin
                    @(posedge clk);
                    if (flag_left)
                        saw_flag_during_pause = 1;
                    expect(running == 1'b0, "CASE3 ball must stay stopped during pause");
                end
                expect(saw_flag_during_pause == 0, "CASE3 no valid left flag during pause");
                expect(score1 == 7'd0 && score2 == 7'd2, "CASE3 score unchanged during invalid press");
            end
        join

        wait_game_idle_and_pause_clear();
        expect(running == 1'b0, "CASE3 after pause clear game is still idle");
        expect(score1 == 7'd0 && score2 == 7'd2, "CASE3 final score still 0:2");

        // ============================================================
        // 场景4：kd1按下后，在蓄力期间出现抖动（非真实释放）
        // 预期：球不启动，直到最终真正松开后才开始移动
        // ============================================================
        $display("\n==== CASE4: kd1 press has bounce during hold, no movement until real release ====");

        // 先正常按下并进入稳定按住
        hold_left_down();
        wait_cycles(8);   // 足够通过按下消抖并进入 S_PRESSED
        expect(running == 1'b0, "CASE4 ball still idle while kd1 is being held");

        // 蓄力期间出现短暂高电平抖动，但未真正释放
        release_left();
        wait_cycles(1);   // 小于释放消抖窗口
        hold_left_down();
        wait_cycles(6);   // 继续保持按下，确认不会误触发

        expect(running == 1'b0, "CASE4 bounce during hold must not start the ball");
        expect(flag_left == 1'b0, "CASE4 no left flag during in-hold bounce");

        // 现在真正释放，并保持稳定
        release_left();
        wait (flag_left == 1'b1);
        wait (running == 1'b1);
        expect(dir == 1'b1, "CASE4 ball starts to the right only after real release");
        expect(ball_pos == 3'd0, "CASE4 serve starts from left edge after real release");

        wait_cycles(5);

        $display("\n==== SUMMARY ====");
        if (fail_count == 0)
            $display("ALL FOUR CASES PASSED");
        else
            $display("TOTAL FAILURES = %0d", fail_count);

        $finish;
    end

    initial begin
        #2_500_000_000;
        $display("[TIMEOUT t=%0t] simulation timeout", $time);
        $display("score1=%0d score2=%0d running=%b dir=%b ball_pos=%0d pause=%b", score1, score2, running, dir, ball_pos, score_pause);
        $finish;
    end

    always @(posedge clk) begin
        if (flag_left || flag_right) begin
            $display("[FLAG t=%0t] left=%b right=%b running=%b dir=%b pos=%0d holdL=%0d holdR=%0d pause=%b",
                     $time, flag_left, flag_right, running, dir, ball_pos,
                     hold_cycles_left, hold_cycles_right, score_pause);
        end
    end
endmodule
