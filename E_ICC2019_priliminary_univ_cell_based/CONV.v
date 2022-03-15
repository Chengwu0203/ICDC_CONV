
`timescale 1ns/10ps

module  CONV(

input		              clk,
input		              reset,
output reg	              busy,
input		              ready,

output reg 	      [11:0]  iaddr,
input  signed	  [19:0]  idata,

output reg         	      cwr,
output reg        [11:0]  caddr_wr,
output reg        [19:0]  cdata_wr,

output reg          	  crd,
output reg        [11:0]  caddr_rd,
input	          [19:0]  cdata_rd,

output reg	      [2:0]   csel

);

////////////////////////////////////////////////
// Kernal0
wire signed [19:0] Kernal [0:8];
wire signed [19:0] Bias;

assign Kernal[0] = 20'h0A89E;      //Pixel 0: 6.586609e-01
assign Kernal[1] = 20'h092D5;      //Pixel 2: 5.735626e-01
assign Kernal[2] = 20'h06D43;      //Pixel 4: 4.268036e-01
assign Kernal[3] = 20'h01004;      //Pixel 6: 6.256104e-02
assign Kernal[4] = 20'hF8F71;      //Pixel 8: -4.396820e-01
assign Kernal[5] = 20'hF6E54;      //Pixel 10: -5.690308e-01
assign Kernal[6] = 20'hFA6D7;      //Pixel 12: -3.482819e-01
assign Kernal[7] = 20'hFC834;      //Pixel 14: -2.179565e-01
assign Kernal[8] = 20'hFAC19;      //Pixel 16: -3.277435e-01

assign Bias      = 20'h01310;      //Pixel 0: 7.446289e-02
////////////////////////////////////////////////
// var

reg [3:0] cnt;
reg [5:0] pos_x, pos_y;
reg [6:0] pos_x_tmp, pos_y_tmp;
reg [4:0] new_x, new_y;
reg [19:0] cmp;
reg signed [39:0] tmp;
wire overflow;

assign overflow = pos_x_tmp[6] | pos_y_tmp[6];
////////////////////////////////////////////////
// state

reg [3:0] cs, ns;
parameter [3:0] IDLE                = 4'h0,
                OVERFLOW_JUDGMENT   = 4'h1,
                READ                = 4'h2,
                CONVOLUTION         = 4'h3,
                RELU                = 4'h4,
                LOAD_0              = 4'h5,
                LOAD_1              = 4'h6,
                LOAD_2              = 4'h7,
                LOAD_3              = 4'h8,
                DELAY               = 4'h9,
                MAX_POOLING         = 4'hA,
                DONE                = 4'hB;

always @(posedge clk or posedge reset)begin
    if(reset)begin
        cs <= IDLE;
    end
    else begin
        cs <= ns;
    end
end

always @(*)begin
    case(cs)
        IDLE:begin
            if(ready)                   ns <= OVERFLOW_JUDGMENT;
            else                        ns <= IDLE;
        end
        OVERFLOW_JUDGMENT:              ns <= READ;
        READ:                           ns <= CONVOLUTION;
        CONVOLUTION:begin
            if(cnt == 4'ha)             ns <= RELU;
            else                        ns <= OVERFLOW_JUDGMENT;
        end
        RELU:begin
            if((&pos_y) && (&pos_x))    ns <= LOAD_0;
            else                        ns <= OVERFLOW_JUDGMENT;
        end
        LOAD_0:                         ns <= LOAD_1;
        LOAD_1:                         ns <= LOAD_2;
        LOAD_2:                         ns <= LOAD_3;
        LOAD_3:                         ns <= DELAY;
        DELAY:                          ns <= MAX_POOLING;
        MAX_POOLING:begin
            // if((&new_y) && (&new_x))    ns <= DONE;
            if(new_y == 0 && new_x == 0)    ns <= DONE;
            else                        ns <= LOAD_0;
        end
        default:                        ns <= IDLE;
    endcase
end
////////////////////////////////////////////////
// cnt

always @(posedge clk or posedge reset)begin
    if(reset)begin
        cnt <= 4'h0;
    end
    else begin
        case(cs)
            CONVOLUTION:        cnt <= cnt + 4'h1;
            RELU:               cnt <= 4'h0;
        endcase
    end
end
////////////////////////////////////////////////
// Layer_0 position

always @(posedge clk or posedge reset)begin
    if(reset)begin
        {pos_y, pos_x} <= 12'h0;
    end
    else begin
        case(cs)
            IDLE:           {pos_y, pos_x} <= 12'h0;
            RELU:           {pos_y, pos_x} <= {pos_y, pos_x} + 12'h1;
        endcase
    end
end
////////////////////////////////////////////////
// Layer_1 position

always @(posedge clk or posedge reset)begin
    if(reset)begin
        {new_y, new_x} <= 10'h0;
    end
    else begin
        case(cs)
            IDLE:           {new_y, new_x} <= 10'h0;
            DELAY:          {new_y, new_x} <= {new_y, new_x} + 10'h1;
        endcase
    end
end
////////////////////////////////////////////////
// addr

always @(posedge clk or posedge reset)begin
    if(reset)begin
        iaddr <= 12'h0;
    end
    else begin
        if(ns == READ)begin
            case(cnt)
                4'h0:  iaddr <= {pos_y - 6'h1, pos_x - 6'h1};
                4'h1:  iaddr <= {pos_y - 6'h1, pos_x       };
                4'h2:  iaddr <= {pos_y - 6'h1, pos_x + 6'h1};
                4'h3:  iaddr <= {pos_y       , pos_x - 6'h1};
                4'h4:  iaddr <= {pos_y       , pos_x       };
                4'h5:  iaddr <= {pos_y       , pos_x + 6'h1};
                4'h6:  iaddr <= {pos_y + 6'h1, pos_x - 6'h1};
                4'h7:  iaddr <= {pos_y + 6'h1, pos_x       };
                4'h8:  iaddr <= {pos_y + 6'h1, pos_x + 6'h1};
            endcase
        end
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        pos_y_tmp <= 4'h0;
    end
    else begin
        if(cs == OVERFLOW_JUDGMENT)begin
            case(cnt)
                4'h0:       pos_y_tmp <= pos_y - 6'h1;
                4'h1:       pos_y_tmp <= pos_y - 6'h1;
                4'h2:       pos_y_tmp <= pos_y - 6'h1;
                4'h3:       pos_y_tmp <= pos_y       ;
                4'h4:       pos_y_tmp <= pos_y       ;
                4'h5:       pos_y_tmp <= pos_y       ;
                4'h6:       pos_y_tmp <= pos_y + 6'h1;
                4'h7:       pos_y_tmp <= pos_y + 6'h1;
                4'h8:       pos_y_tmp <= pos_y + 6'h1;
                default:    pos_y_tmp <= 4'h0;
            endcase
        end
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        pos_x_tmp <= 4'h0;
    end
    else begin
        if(cs == OVERFLOW_JUDGMENT)begin
            case(cnt)
                4'h0:  pos_x_tmp <= pos_x - 6'h1;
                4'h1:  pos_x_tmp <= pos_x       ;
                4'h2:  pos_x_tmp <= pos_x + 6'h1;
                4'h3:  pos_x_tmp <= pos_x - 6'h1;
                4'h4:  pos_x_tmp <= pos_x       ;
                4'h5:  pos_x_tmp <= pos_x + 6'h1;
                4'h6:  pos_x_tmp <= pos_x - 6'h1;
                4'h7:  pos_x_tmp <= pos_x       ;
                4'h8:  pos_x_tmp <= pos_x + 6'h1;
                default:    pos_x_tmp <= 4'h0;
            endcase
        end
    end
end
////////////////////////////////////////////////
// CONV

always @(posedge clk or posedge reset)begin
    if(reset)begin
        tmp <= 40'h0;
    end
    else begin
        if(cs == CONVOLUTION)begin
            if(cnt < 4'h9)begin
                if(!overflow)begin
                    tmp <= tmp + (idata * Kernal[cnt]);
                end
                else begin
                    tmp <= tmp;
                end
            end
            else if(cnt == 4'h9)begin
                tmp <= tmp + ({Bias,16'h0});
            end
        end
        else if((cs == RELU)) begin
            tmp <= 0;
        end

    end
end
////////////////////////////////////////////////
// MEM CTRL

always @(posedge clk or posedge reset)begin
    if(reset)begin
        csel <= 3'h0;
    end
    else begin
        case(ns)
            RELU:           csel <= 3'h1;
            LOAD_0:         csel <= 3'h1;
            LOAD_1:         csel <= 3'h1;
            LOAD_2:         csel <= 3'h1;
            LOAD_3:         csel <= 3'h1;
            MAX_POOLING:    csel <= 3'h3;
            default:        csel <= 3'h0;
        endcase
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        cwr <= 1'h0;
    end
    else begin
        case(ns)
            RELU:           cwr <= 1'h1;
            MAX_POOLING:    cwr <= 1'h1;
            default:        cwr <= 1'h0;
        endcase
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        crd <= 1'h0;
    end
    else begin
        case(ns)
            LOAD_0:         crd <= 1'h1;
            LOAD_1:         crd <= 1'h1;
            LOAD_2:         crd <= 1'h1;
            LOAD_3:         crd <= 1'h1;
            default:        crd <= 1'h0;
        endcase
    end
end
////////////////////////////////////////////////
// MEM DATA

always @(posedge clk or posedge reset)begin
    if(reset)begin
        caddr_rd <= 12'h0;
    end
    else begin
        case(ns)
            LOAD_0:         caddr_rd <= { {new_y, 1'h0},          {new_x, 1'h0}};
            LOAD_1:         caddr_rd <= { {new_y, 1'h0},         ({new_x, 1'h0} + 6'h1)};
            LOAD_2:         caddr_rd <= {({new_y, 1'h0} + 6'h1),  {new_x, 1'h0}};
            LOAD_3:         caddr_rd <= {({new_y, 1'h0} + 6'h1), ({new_x, 1'h0} + 6'h1)};
            default:        caddr_rd <= caddr_rd;
        endcase
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        caddr_wr <= 12'h0;
    end
    else begin
        case(ns)
            RELU:           caddr_wr <= {pos_y, pos_x};
            MAX_POOLING:    caddr_wr <= {new_y, new_x};
            default:        caddr_wr <= caddr_wr;
        endcase
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        cdata_wr <= 20'h0;
    end
    else begin
        case(ns)
            RELU:begin
                if(tmp[35])begin
                        cdata_wr <= 20'h0;
                end
                else begin
                        cdata_wr <= tmp[35:16] + tmp[15];
                end
            end
            MAX_POOLING:begin
                cdata_wr <= cmp;
            end
            default:    cdata_wr <= 20'h0;
        endcase
    end
end
////////////////////////////////////////////////
// compare

always @(posedge clk or posedge reset)begin
    if(reset)begin
        cmp <= 20'h0;
    end
    else begin
        case(cs)
            LOAD_0:         cmp <= cdata_rd;
            LOAD_1, LOAD_2, LOAD_3:         cmp <= (cmp > cdata_rd) ? cmp : cdata_rd;
            // :         cmp <= (cmp > cdata_rd) ? cmp : cdata_rd;
            // :         cmp <= (cmp > cdata_rd) ? cmp : cdata_rd;
            // default:        cmp <= 20'h0;
        endcase
    end
end
////////////////////////////////////////////////
// control

always @(posedge clk or posedge reset)begin
    if(reset)begin
        busy <= 1'h0;
    end
    else begin
        case(ns)
            OVERFLOW_JUDGMENT:  busy <= 1'h1;
            DONE:               busy <= 1'h0;
        endcase
    end
end
////////////////////////////////////////////////

endmodule
