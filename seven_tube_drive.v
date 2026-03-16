module seven_tube_drive (
    input  wire [6:0] left_num,
    input  wire [6:0] right_num,
    output wire [13:0] seven_segment //输出2个数码管的7段码，共14位
);
    wire [3:0] data_0; //右侧得分
    
    wire [3:0] data_5; //左侧得分

    show_data_sel u_show_data_sel (
        .left_num (left_num),
        .right_num(right_num),
        .data_0   (data_0),
        
        .data_5   (data_5)
    );

    single_seven_tube_drive u_seg0 (.data(data_0), .seven_segment(seven_segment[ 6: 0]));
    
    single_seven_tube_drive u_seg5 (.data(data_5), .seven_segment(seven_segment[13:7]));
endmodule


module single_seven_tube_drive (
    input  wire [3:0] data,
    output reg  [6:0] seven_segment
);
    /*
     * 七段码采用低电平点亮方式：
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
    output wire [3:0] data_0, //右边数码管数据代表右侧比分
    
    output wire [3:0] data_5 //左侧数码管数据代表左侧比分
);
    
    assign data_0 = right_num[3:0];
    
    assign data_5 = left_num[3:0];
    
endmodule


