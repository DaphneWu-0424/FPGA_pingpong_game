module seven_tube_drive (
    input  wire [6:0] left_num,
    input  wire [6:0] right_num,
    output wire [41:0] seven_segment //输出6个数码管的7段码，共42位，显式格式位"xx--xx"
);
    wire [3:0] data_0;
    wire [3:0] data_1;
    wire [3:0] data_2;
    wire [3:0] data_3;
    wire [3:0] data_4;
    wire [3:0] data_5;

    show_data_sel u_show_data_sel (
        .left_num (left_num),
        .right_num(right_num),
        .data_0   (data_0),
        .data_1   (data_1),
        .data_2   (data_2),
        .data_3   (data_3),
        .data_4   (data_4),
        .data_5   (data_5)
    );

    single_seven_tube_drive u_seg0 (.data(data_0), .seven_segment(seven_segment[ 6: 0]));
    single_seven_tube_drive u_seg1 (.data(data_1), .seven_segment(seven_segment[13: 7]));
    single_seven_tube_drive u_seg2 (.data(data_2), .seven_segment(seven_segment[20:14]));
    single_seven_tube_drive u_seg3 (.data(data_3), .seven_segment(seven_segment[27:21]));
    single_seven_tube_drive u_seg4 (.data(data_4), .seven_segment(seven_segment[34:28]));
    single_seven_tube_drive u_seg5 (.data(data_5), .seven_segment(seven_segment[41:35]));
endmodule


module single_seven_tube_drive (
    input  wire [3:0] data,
    output reg  [6:0] seven_segment
);
    /*
     * 七段码采用常见的低电平点亮方式：
     * seven_segment = {a,b,c,d,e,f,g}
     * 4'ha 显示中间横杠 '-'
     * 4'hf 显示空白
     */
    always @(*) begin
        case (data)
            4'd0 : seven_segment = 7'b100_0000;
            4'd1 : seven_segment = 7'b111_1001;
            4'd2 : seven_segment = 7'b010_0100;
            4'd3 : seven_segment = 7'b011_0000;
            4'd4 : seven_segment = 7'b001_1001;
            4'd5 : seven_segment = 7'b001_0010;
            4'd6 : seven_segment = 7'b000_0010;
            4'd7 : seven_segment = 7'b111_1000;
            4'd8 : seven_segment = 7'b000_0000;
            4'd9 : seven_segment = 7'b001_0000;
            4'ha : seven_segment = 7'b011_1111; //显式横杠，g亮其余全灭
            4'hf : seven_segment = 7'b111_1111; //显示空白，全灭
            default: seven_segment = 7'b111_1111;
        endcase
    end
endmodule


module show_data_sel (
    input  wire [6:0] left_num,
    input  wire [6:0] right_num,
    output wire [3:0] data_0, //最右边数码管数据
    output wire [3:0] data_1,
    output wire [3:0] data_2,
    output wire [3:0] data_3,
    output wire [3:0] data_4,
    output wire [3:0] data_5
);
    wire [7:0] left_digits;
    wire [7:0] right_digits;

    function [7:0] split_decimal_2digits; //输入7位数字，输出为8为，将0-99之间的数拆分为十位数字和个位数字，各自占据4位
        input [6:0] num;
        begin
            if      (num >= 7'd90) split_decimal_2digits = {4'd9, num - 7'd90};
            else if (num >= 7'd80) split_decimal_2digits = {4'd8, num - 7'd80};
            else if (num >= 7'd70) split_decimal_2digits = {4'd7, num - 7'd70};
            else if (num >= 7'd60) split_decimal_2digits = {4'd6, num - 7'd60};
            else if (num >= 7'd50) split_decimal_2digits = {4'd5, num - 7'd50};
            else if (num >= 7'd40) split_decimal_2digits = {4'd4, num - 7'd40};
            else if (num >= 7'd30) split_decimal_2digits = {4'd3, num - 7'd30};
            else if (num >= 7'd20) split_decimal_2digits = {4'd2, num - 7'd20};
            else if (num >= 7'd10) split_decimal_2digits = {4'd1, num - 7'd10};
            else                    split_decimal_2digits = {4'd0, num[3:0]};
        end
    endfunction

    assign left_digits  = split_decimal_2digits(left_num);
    assign right_digits = split_decimal_2digits(right_num);

    assign data_0 = right_digits[3:0];
    assign data_1 = (right_num >= 7'd10) ? right_digits[7:4] : 4'hf;
    assign data_2 = 4'ha;
    assign data_3 = 4'ha;
    assign data_4 = left_digits[3:0];
    assign data_5 = (left_num >= 7'd10) ? left_digits[7:4] : 4'hf;
endmodule


