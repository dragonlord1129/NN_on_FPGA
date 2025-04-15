`include "include.v"
module  weight_memory #( 
    parameter numWeight = 3, neuronNo = 5, layerNo = 1, addressWidth = 10, dataWidth = 16, weightFile=""
) (
    input clk,
    input wen, //writeEnable
    input ren, //readEnable
    input [addressWidth-1:0] waddr, raddr, //writeAddress, readAddress
    input [dataWidth-1:0] win, //input data
    output reg [dataWidth-1:0] wout 
);
    reg [dataWidth-1:0] mem [numWeight-1:0];
    `ifdef pretrained // AS A ROM
        initial begin
            $readmemb(weightFile, mem);
        end
    else
        always @(posedge clk ) begin // AS A RAM
            if(wen) begin
                mem[waddr] <= win;
            end
        end
    `endif 
    always @(posedge clk ) begin
        if(ren) begin
            wout <= mem[raddr];
        end
    end    
endmodule