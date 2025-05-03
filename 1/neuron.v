`include "include.v"
module neuron #( 
    parameter layerNo=0, neuronNo=0, numWeight=784, dataWidth=16, sigmoidSize=5, weightInWidth=1, actType="relu", biasFile="", weightFile="",
) (
    input clk, rst,
    input myInputValid, weightValid, biasValid,
    input[dataWidth-1:0] myInput,
    input [31:0] weightValue, biasValue, configLayerNum, configNeuronNum,

    output [dataWidth-1:0] out,
    output reg outvalid
);
    parameter addressWidth = $clog2(numweight);

    reg wen;
    reg [addressWidth-1:0] w_addr;
    reg [addressWidth:0] r_addr; //read address has to reach numWeight hence the width is 1 bit more
    reg [dataWidth-1:0] w_in, 
    reg [2*dataWidth-1:0] mul, sum, bias;
    reg [2*dataWidth-1:0] myInputd;
    reg [31:0] biasReg[0:0];
    reg weight_valid, mult_valid, sigValid, mux_valid_d, mux_valid_f;
    reg addr=0;

    wire ren;
    wire [dataWidth-1:0] w_out;
    wire mux_valid;
    wire [2*dataWidth:0] comboAdd, biasAdd;

    always @(posedge clk ) begin // Loading weight values into the memory
        if(rst) begin
            w_addr <= {addressWidth{1'b1}};
            wen <= 0;
        end
        else if(weightValid & (configLayerNum == layerNo) & (configNeuronNum == neuronNo)) begin
            w_in <= weightValue;
            w_addr <= w_addr + 1;
            wen <= 1            
        end
        else wen <= 0;
    end

    assign mux_valid = mult_valid;
    assign comboAdd = mul + sum;
    assign biasAdd = bias + sum;
    assign ren = myInputValid;

    `ifdef pretrained
        initial begin
            $readmemb(biasFile, biasReg);
        end
        always @(posedge clk ) begin
            bias <= {biasReg[addr][dataWidth-1:0], {dataWidth{1'b0}}}; // left-shifting the dataWidth bits into the higher part of a 2*dataWidth-bits
        end
    `else
        always @(posedge clk) begin
            if(biasValid & (configLayerNum == layerNo) & (configNeuronNum == neuronNo)) bias <= {biasValue[dataWidth-1:0], {dataWidth{1'b0}}};
        end
    `endif 

    always @(posedge clk) begin
        if(rst|outvalid) begin
            r_addr <= 0;
        end
        else if(myInputValid) begin
            r_addr = r_addr + 1;
        end
    end
    always @(posedge clk) begin
        mul <= $signed(myInputd) * $signed(w_out);
    end

    always @(posedge clk) begin
        if(rst|outvalid) begin
            sum <= 0;
        end
        else if((r_addr == numWeight) & mux_valid_f) begin
            if(!bias[2*dataWidth-1] & !sum[2*dataWidth-1] & BiasAdd[2*dataWidth-1]) begin // If adding both positive bias and sum results in sign bit 1, we saturate by making sign bit 0 and rest of the bits 1
                sum[2*dataWidth-1] <= 1'b0;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b1}};                
            end 
            else if(bias[2*dataWidth-1] & sum[2*dataWidth-1] & !BiasAdd[2*dataWidth-1]) begin // If adding both negative bias and sum results in sign bit 0, we saturate by making sign bit 1 and rest of the bits 0
                sum[2*dataWidth-1] <= 1'b1;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b0}};
            end
            else sum<= BiasAdd;
        end
        else if(mux_valid) begin
            if(!mul[2*dataWidth-1] & !sum[2*dataWidth-1] & comboAdd[2*dataWidth-1]) begin
                sum[2*dataWidth-1] <= 1'b0;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b1}};
            end
            else if(mul[2*dataWidth-1] & sum[2*dataWidth-1] & !comboAdd[2*dataWidth-1]) begin
                sum[2*dataWidth-1] <= 1'b1;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b0}};
            end
            else sum <= comboAdd;
        end
    end
    always @(posedge clk) begin
        myInputd <= myInput;
        weight_valid <= myInputValid;
        mult_valid <= weight_valid;
        sigValid <= ((r_addr == numWeight) & mux_valid_f) ? 1'b1 : 1'b0;
        outvalid <= sigValid;
        mux_valid_d <= mux_valid;
        mux_valid_f <= !mux_valid & mux_valid_d;
    end

    weight_memory #(parameter numWeight(numWeight), neuronNo(neuronNo), layerNo(layerNo), addressWidth(addressWidth), dataWidth(dataWidth), weightFile="weightFile") WM(
        .clk(clk),
        .wen(wen),
        .ren(ren),
        .waddr(w_addr),
        .raddr(r_addr),
        .win(w_in),
        .wout(w_out)
    );
    generate
        if(actType == "sigmoid") begin:siginst
            Sig            
        end
    endgenerate

endmodule