`timescale 1ns/1ps

module tb_pingpong_game_rewrite;

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
    wire dig_oe_n;

    // 为了加快仿真，把大计数参数都压小
    pingpong_game #(
        .BALL_STEP_CYCLES   (20),
        .DEBOUNCE_CYCLES    (4),
        .BEEP_CYCLES        (20),
        .HOLD_UNIT_CYCLES   (8),
        .SPEED_LEVEL_MAX    (7),
        .MIN_CROSS_COUNT    (4),
        .SCORE_PAUSE_CYCLES (30)
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
        .dig_oe_n (dig_oe_n)
    );

    // 方便观察内部状态
    wire        running           = uut.running;
    wire        dir               = uut.dir;
    wire [2:0]  ball_pos          = uut.ball_pos;
    wire        flag_left         = uut.flag_left;
    wire        flag_right        = uut.flag_right;
    wire [31:0] hold_cycles_left  = uut.hold_cycles_left;
    wire [31:0] hold_cycles_right = uut.hold_cycles_right;
    wire [3:0]  speed_level       = uut.speed_level;
    wire [31:0] step_cycles       = uut.step_cycles;
    wire [63:0] frame_data        = uut.u_seven_tube_drive.full_data;

    // 100MHz 时钟
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // 按键：低电平按下，高电平松开
    task press_left;
        input integer hold_clk_cycles;
        integer i;
        begin
            @(negedge clk);
            kd1 = 1'b0;
            for (i = 0; i < hold_clk_cycles; i = i + 1)
                @(negedge clk);
            kd1 = 1'b1;
            repeat (12) @(negedge clk);
        end
    endtask

    task press_right;
        input integer hold_clk_cycles;
        integer i;
        begin
            @(negedge clk);
            kd2 = 1'b0;
            for (i = 0; i < hold_clk_cycles; i = i + 1)
                @(negedge clk);
            kd2 = 1'b1;
            repeat (12) @(negedge clk);
        end
    endtask

    // 等球到最左/最右，方便做“到位击球”测试
    task wait_ball_at_left;
        begin
            while (!(running && !dir && ball_pos == 3'd0))
                @(posedge clk);
            repeat (2) @(posedge clk);
        end
    endtask

    task wait_ball_at_right;
        begin
            while (!(running && dir && ball_pos == 3'd7))
                @(posedge clk);
            repeat (2) @(posedge clk);
        end
    endtask

    // 监视数码管串行输出：在 SCK 上升沿采样 SI，RCK 上升沿打印一帧
    reg [63:0] cap_shift;
    reg [6:0]  cap_cnt;

    initial begin
        cap_shift = 64'd0;
        cap_cnt   = 7'd0;
    end

    always @(posedge SCK) begin
        cap_shift <= {SI, cap_shift[63:1]};
        if (cap_cnt < 7'd64)
            cap_cnt <= cap_cnt + 1'b1;
    end

    always @(posedge RCK) begin
        $display("[LATCH t=%0t] oe=%b frame=%h cap=%h bits=%0d score1=%0d score2=%0d",
                 $time, dig_oe_n, frame_data, cap_shift, cap_cnt, score1, score2);
        cap_cnt <= 7'd0;
    end

    // 只在关键状态变化时打印，避免刷屏
    reg        running_d;
    reg        dir_d;
    reg [2:0]  ball_pos_d;
    reg [7:0]  led_d;
    reg [6:0]  score1_d;
    reg [6:0]  score2_d;
    reg        beep_d;
    reg [3:0]  speed_level_d;
    reg [31:0] step_cycles_d;

    initial begin
        running_d     = 1'b0;
        dir_d         = 1'b0;
        ball_pos_d    = 3'd0;
        led_d         = 8'd0;
        score1_d      = 7'd0;
        score2_d      = 7'd0;
        beep_d        = 1'b0;
        speed_level_d = 4'd0;
        step_cycles_d = 32'd0;
    end

    always @(posedge clk) begin
        if (flag_left || flag_right) begin
            $display("[FLAG  t=%0t] left=%b right=%b holdL=%0d holdR=%0d run=%b dir=%b pos=%0d spd=%0d step=%0d",
                     $time, flag_left, flag_right, hold_cycles_left, hold_cycles_right,
                     running, dir, ball_pos, speed_level, step_cycles);
        end

        if ((running     !== running_d)     ||
            (dir         !== dir_d)         ||
            (ball_pos    !== ball_pos_d)    ||
            (led         !== led_d)         ||
            (score1      !== score1_d)      ||
            (score2      !== score2_d)      ||
            (beep        !== beep_d)        ||
            (speed_level !== speed_level_d) ||
            (step_cycles !== step_cycles_d)) begin

            $display("[STATE t=%0t] run=%b dir=%b pos=%0d led=%b score1=%0d score2=%0d beep=%b spd=%0d step=%0d",
                     $time, running, dir, ball_pos, led, score1, score2, beep, speed_level, step_cycles);

            running_d     <= running;
            dir_d         <= dir;
            ball_pos_d    <= ball_pos;
            led_d         <= led;
            score1_d      <= score1;
            score2_d      <= score2;
            beep_d        <= beep;
            speed_level_d <= speed_level;
            step_cycles_d <= step_cycles;
        end
    end

    initial begin
        rst_n = 1'b0;
        kd1   = 1'b1;
        kd2   = 1'b1;

        repeat (10) @(negedge clk);
        rst_n = 1'b1;
        repeat (10) @(negedge clk);

        // CASE1：左边长按发球，应该明显“先快后慢”
        $display("\n==== CASE1: 左边长按发球，观察先快后慢 ====");
        press_left(40);
        repeat (220) @(negedge clk);

        // CASE2：等待球真正到右端，再右边回球
        $display("\n==== CASE2: 右边到位后回球 ====");
        wait_ball_at_right();
        press_right(40);
        repeat (220) @(negedge clk);

        // CASE3：左边提前击球，应该判右方得分
        $display("\n==== CASE3: 左边提前击球，右方得分 ====");
        press_left(24);
        repeat (20) @(negedge clk);
        press_left(10);
        repeat (120) @(negedge clk);

        // CASE4：重新发球后，右边提前击球，应该判左方得分
        $display("\n==== CASE4: 右边提前击球，左方得分 ====");
        press_left(24);
        repeat (30) @(negedge clk);
        press_right(12);
        repeat (120) @(negedge clk);

        $display("\n==== FINAL ====");
        $display("score1=%0d score2=%0d led=%b beep=%b running=%b dir=%b pos=%0d spd=%0d step=%0d",
                 score1, score2, led, beep, running, dir, ball_pos, speed_level, step_cycles);
        $finish;
    end

    initial begin
        #500000;
        $display("[TIMEOUT] simulation timeout");
        $finish;
    end

endmodule