module key_processor #(
    parameter integer DEBOUNCE_CYCLES = 500_000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        kd1,
    input  wire        kd2,
    output wire        flag_left,
    output wire        flag_right,
    output wire [31:0] hold_cycles_left,
    output wire [31:0] hold_cycles_right,
    output wire [31:0] hold_cycles_live_left,
    output wire [31:0] hold_cycles_live_right
);
    key_filter #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) u_key_filter_left (
        .clk        (clk),
        .rst_n      (rst_n),
        .enable     (enable),
        .key_n      (kd1),
        .flag       (flag_left),
        .hold_cycles(hold_cycles_left),
        .hold_cycles_live(hold_cycles_live_left)
    );

    key_filter #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) u_key_filter_right (
        .clk        (clk),
        .rst_n      (rst_n),
        .enable     (enable),
        .key_n      (kd2),
        .flag       (flag_right),
        .hold_cycles(hold_cycles_right),
        .hold_cycles_live(hold_cycles_live_right)
    );
endmodule


module key_filter #(
    parameter integer DEBOUNCE_CYCLES = 500_000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        key_n,
    output reg        flag,
    output wire [31:0] hold_cycles,
    output wire [31:0] hold_cycles_live
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
    reg [31:0] hold_cycles_latched;

    wire key_pressed = (key_ff1 == 1'b1);
    wire key_released = (key_ff1 == 1'b0);
    
    assign hold_cycles   = hold_cycles_latched;
    assign hold_cycles_live = hold_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_ff0 <= 1'b0;
            key_ff1 <= 1'b0;
        end else begin
            key_ff0 <= key_n;
            key_ff1 <= key_ff0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state               <= S_IDLE;
            cnt                 <= 32'd0;
            hold_cnt            <= 32'd0;
            hold_cycles_latched <= 32'd0;
            flag                <= 1'b0;
        end else if (!enable) begin
            state               <= S_IDLE;
            cnt                 <= 32'd0;
            hold_cnt            <= 32'd0;
            hold_cycles_latched <= 32'd0;
            flag                <= 1'b0;
        end else begin
            flag                <= 1'b0; //默认拉低，只在合法释放完成时打一拍
            case (state)
                S_IDLE: begin
                    cnt      <= 32'd0;
                    hold_cnt <= 32'd0;
                    if (key_pressed) begin
                        if (DEBOUNCE_CYCLES <= 1) begin
                            state    <= S_PRESSED;
                            hold_cnt <= 32'd0;
                        end else begin
                            state <= S_DB_PRESS;
                            cnt   <= 32'd1;
                        end
                    end
                end

                S_DB_PRESS: begin
                    if (key_pressed) begin
                        if (cnt >= DEBOUNCE_CYCLES - 1) begin
                            state    <= S_PRESSED;
                            cnt      <= 32'd0;
                            hold_cnt <= 32'd0;
                        end else begin
                            cnt <= cnt + 1'b1;
                        end
                    end else begin
                        state <= S_IDLE;
                        cnt   <= 32'd0;
                    end
                end

                S_PRESSED: begin
                    if (key_pressed) begin
                        if (hold_cnt != 32'hffff_ffff)
                            hold_cnt <= hold_cnt + 1'b1;
                    end else begin
                        hold_cycles_latched <= hold_cnt; //先锁存蓄力值
                        state               <= S_WAIT_HIGH;
                        cnt                 <= 32'd1; //开始做释放消抖
                    end
                end

                S_WAIT_HIGH: begin
                    if (key_released) begin
                        if ((DEBOUNCE_CYCLES <= 1) || (cnt >= DEBOUNCE_CYCLES - 1)) begin
                            flag  <= 1'b1; //释放稳定后，才真正触发
                            state <= S_IDLE;
                            cnt   <= 32'd0;
                        end else begin
                            cnt <= cnt + 1'b1;
                        end
                    end else begin
                        state <= S_PRESSED;
                        cnt   <= 32'd0;
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
