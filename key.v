module key_processor #(
    parameter integer DEBOUNCE_CYCLES = 500_000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        kd1,
    input  wire        kd2,
    output wire        flag_left,
    output wire        flag_right,
    output wire [31:0] hold_cycles_left,
    output wire [31:0] hold_cycles_right
);
    key_filter #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) u_key_filter_left (
        .clk        (clk),
        .rst_n      (rst_n),
        .key_n      (kd1),
        .flag       (flag_left),
        .hold_cycles(hold_cycles_left)
    );

    key_filter #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) u_key_filter_right (
        .clk        (clk),
        .rst_n      (rst_n),
        .key_n      (kd2),
        .flag       (flag_right),
        .hold_cycles(hold_cycles_right)
    );
endmodule


module key_filter #(
    parameter integer DEBOUNCE_CYCLES = 500_000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        key_n,
    output reg         flag,
    output reg [31:0]  hold_cycles
);
    localparam [1:0] S_IDLE      = 2'd0;
    localparam [1:0] S_DB_PRESS  = 2'd1;
    localparam [1:0] S_PRESSED   = 2'd2;
    localparam [1:0] S_WAIT_HIGH = 2'd3;

    reg        key_ff0;
    reg        key_ff1;
    reg [1:0]  state;
    reg [31:0] cnt;
    reg [31:0] hold_cnt;

    /*
     * 按键默认高电平，按下为低电平。
     * 先对“按下”做消抖，确认稳定按下后开始累计稳定低电平持续时间。
     * 当按键释放时，输出一个周期的 flag，
     * 同时把本次稳定低电平持续时间锁存到 hold_cycles。
     * 这样主模块就可以把“按住多久”映射成发球/回球初速度。
     */

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_ff0 <= 1'b1;
            key_ff1 <= 1'b1;
        end else begin
            key_ff0 <= key_n;
            key_ff1 <= key_ff0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            cnt         <= 32'd0;
            hold_cnt    <= 32'd0;
            hold_cycles <= 32'd0;
            flag        <= 1'b0;
        end else begin
            flag <= 1'b0;

            case (state)
                S_IDLE: begin
                    cnt      <= 32'd0;
                    hold_cnt <= 32'd0;
                    if (key_ff1 == 1'b0) begin
                        state <= S_DB_PRESS;
                        cnt   <= 32'd1;
                    end
                end

                S_DB_PRESS: begin
                    if (key_ff1 == 1'b0) begin
                        if (cnt < DEBOUNCE_CYCLES) begin
                            cnt <= cnt + 1'b1;
                        end else begin
                            state    <= S_PRESSED;
                            cnt      <= 32'd0;
                            hold_cnt <= 32'd0;
                        end
                    end else begin
                        state <= S_IDLE;
                        cnt   <= 32'd0;
                    end
                end

                S_PRESSED: begin
                    if (key_ff1 == 1'b0) begin
                        if (hold_cnt != 32'hffff_ffff)
                            hold_cnt <= hold_cnt + 1'b1;
                    end else begin
                        flag        <= 1'b1;
                        hold_cycles <= hold_cnt;
                        state       <= S_WAIT_HIGH;
                        cnt         <= 32'd0;
                    end
                end

                S_WAIT_HIGH: begin
                    if (key_ff1 == 1'b1) begin
                        if (cnt < DEBOUNCE_CYCLES - 1) begin
                            cnt <= cnt + 1'b1;
                        end else begin
                            state <= S_IDLE;
                            cnt   <= 32'd0;
                        end
                    end else begin
                        cnt <= 32'd0;
                    end
                end

                default: begin
                    state <= S_IDLE;
                    cnt   <= 32'd0;
                end
            endcase
        end
    end
endmodule
