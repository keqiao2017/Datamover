module fibonacci_v7_2(
	//inputs
	clk,
	rst_n,
	s_axis_s2mm_tready,
	s_axis_s2mm_cmd_tready,
	ap_start,
	//outputs
	s_axis_s2mm_tdata,
	s_axis_s2mm_cmd_tdata,
	s_axis_s2mm_tvalid,
	s_axis_s2mm_tlast,
	ap_done,
	s_axis_s2mm_cmd_tvalid
	);

	//inputs
input clk;
input rst_n;
input s_axis_s2mm_tready;
input s_axis_s2mm_cmd_tready;
input ap_start;
	//outputs
output reg s_axis_s2mm_cmd_tvalid;
output reg s_axis_s2mm_tvalid;
output reg [255:0] s_axis_s2mm_tdata;
output reg [103:0] s_axis_s2mm_cmd_tdata;
output reg ap_done;
output reg s_axis_s2mm_tlast;
	//inner registers
reg[255:0] memory [24:0];
reg [4:0] addr;
reg [2:0] cur_state;
reg [2:0] next_state;
reg [4:0] data_cnt; //data send count
reg [6:0] wait_cnt;
reg  wait_begin;
reg ap_done1;

//initial memory for fibonacci
integer i;
always @(posedge clk ) begin
	if (!rst_n) begin
		// reset
		addr <= 5'b0;
	end
	else begin
	if (addr < 5'd24) begin
		addr <= addr +1'b1;
	end
	else 
		addr <= 5'b0;	
	end
end
//initial memory for fibonacci
always @(posedge clk ) begin
	if (!rst_n) begin
	// clear memory
	for(i=0;i<25;i=i+1)
	memory [i] <= 256'b0;
	end
	else begin
	memory[0] <= 256'd0; 
	memory[1] <= 256'd1;
	if (addr > 0) begin
	memory[addr+1'b1] <= memory[addr-1'b1] + memory [addr];
	end
	end
end

//state machine change routes: 
//IDLE --SENDCMD1--SENDCMD2--WAIT1 --SENDDATA1-WAIT2-SENDADTA2--IDLE

localparam SystemIDLE =4'd0;
localparam SendCMD1   =4'd1;
localparam Wait1      =4'd2;
localparam SendDATA1  =4'd3;
localparam Wait2      =4'd4;
localparam SendCMD2	  =4'd5;
localparam SendDATA2  =4'd7;
localparam StopDATA1  =4'd8;
localparam StopDATA2  =4'd9;
//wait cnt generate 
always @(posedge clk ) begin
	if (!rst_n || !wait_begin) begin
		wait_cnt <= 7'b0;
	end
	else begin
	if (wait_begin) begin
		wait_cnt <= wait_cnt + 1'b1;
		end
	end
end


always @(posedge clk ) begin
	if (!rst_n) begin
		cur_state <= SystemIDLE;
	end
	else begin
		cur_state <= next_state;
	end
end

always @(*) begin
	if (!rst_n) begin
	next_state	= SystemIDLE;
	end
	else begin
	case(cur_state)
	SystemIDLE:
		begin
		if (s_axis_s2mm_cmd_tready && ap_start && !ap_done) begin
			  	next_state = SendCMD1;
		end
		else    next_state = SystemIDLE;
		end
	SendCMD1:
		begin
				next_state = SendCMD2;
		end
	SendCMD2:
		begin
				next_state =  Wait1;
		end
	Wait1:   //wait between cmd & data
		begin
			if (wait_cnt == 4'd10) begin
				next_state = SendDATA1;
			end
			else begin
				next_state = Wait1;
			end
		end

	SendDATA1:
		begin
			if (!s_axis_s2mm_tready) begin
				next_state = StopDATA1;
			end
			else if (ap_done1) begin
				next_state = Wait2;
			end 
			else begin
				next_state = SendDATA1;
			end
		end
	Wait2: //wait after one transefer
		begin
			if (s_axis_s2mm_cmd_tready) begin
				next_state = SendDATA2;
			end
			else begin
				next_state = Wait2;
			end
		end
	SendDATA2:
		begin
			if (!s_axis_s2mm_tready) begin
				next_state = StopDATA2;
			end
			else if (ap_done) begin
				next_state = SystemIDLE;
			end 
			else begin
				next_state = SendDATA2;
			end
		end
	StopDATA1:
		begin
			if(s_axis_s2mm_tready) begin
				next_state = SendDATA1;
			end
			else begin
				next_state = StopDATA1;
			end
		end
	StopDATA2:
		begin
			if (s_axis_s2mm_tready) begin
				next_state = SendDATA2;
			end 
			else begin
				next_state =StopDATA2;			
			end
		end

	default:
				next_state = SystemIDLE;
	endcase
end
end



always @(posedge clk ) begin
	if (!rst_n) begin
			s_axis_s2mm_cmd_tvalid <= 1'b0;
			s_axis_s2mm_tvalid     <= 1'b0;
			s_axis_s2mm_cmd_tdata  <= 104'b0;
			s_axis_s2mm_tdata      <= 256'b0;
			data_cnt			   <= 5'b0;	
			ap_done1               <= 1'b0;
			ap_done				   <= 1'b0;
			wait_begin		   	   <= 1'b0;
			s_axis_s2mm_tlast      <= 1'b0;
	end
	else 
	begin
		case(next_state)
		SystemIDLE:
		begin
			s_axis_s2mm_tvalid     <= 1'b0;
			s_axis_s2mm_tdata      <= 256'b0;
			s_axis_s2mm_cmd_tvalid <= 1'b0;
			s_axis_s2mm_cmd_tdata  <= 104'b0;
			s_axis_s2mm_tlast      <= 1'b0;
		end
		SendCMD1:
		begin
			s_axis_s2mm_cmd_tvalid <= 1'b1;
			s_axis_s2mm_cmd_tdata  <= {8'h00,64'h0a00_0000,8'h40,1'b1,23'd1200};
		end
		SendCMD2:
		begin
			s_axis_s2mm_cmd_tvalid <= 1'b1;
			s_axis_s2mm_cmd_tdata  <= {8'h00,64'h0010_0000,8'h40,1'b1,23'd1200};
		end
		Wait1:  //wait between cmd & data
			begin
			wait_begin             <= 1'b1;
			s_axis_s2mm_cmd_tvalid <= 1'b0;
			s_axis_s2mm_cmd_tdata  <= 104'b0;
			s_axis_s2mm_tdata      <= 256'b0;
			s_axis_s2mm_tvalid     <= 1'b0;
			end
		SendDATA1:
		begin
			wait_begin		   	   <= 1'b0;
			s_axis_s2mm_cmd_tvalid <= 1'b0;
			s_axis_s2mm_cmd_tdata  <= 104'b0;
			s_axis_s2mm_tvalid 	   <= 1'b1;
			s_axis_s2mm_tdata 	   <= memory[data_cnt];
			 if (data_cnt == 5'd7) begin
			 ap_done1 			   <= 1'b1;
			 s_axis_s2mm_tlast 	   <= 1'b1;
			 data_cnt 			   <= data_cnt +1'b1;
			 end 
			 else begin 
			 data_cnt		       <= data_cnt +1'b1;
			 end
		end
		Wait2:  //wait between one transfer data
		begin
			wait_begin			   <= 1'b1;
			s_axis_s2mm_cmd_tvalid <= 1'b0;
			s_axis_s2mm_cmd_tdata  <= 104'b0;
			s_axis_s2mm_tdata      <= 256'b0;
			s_axis_s2mm_tvalid     <= 1'b0;
		end
		SendDATA2:
		begin
			wait_begin		   	   <= 1'b0;
			s_axis_s2mm_cmd_tvalid <= 1'b0;
			s_axis_s2mm_cmd_tdata  <= 104'b0;
			s_axis_s2mm_tvalid 	   <= 1'b1;
			s_axis_s2mm_tdata 	   <= memory[data_cnt];
			if (data_cnt == 5'd24) begin
				ap_done            <= 1'b1;
				s_axis_s2mm_tlast  <= 1'b1;
			end 
			else begin 
				data_cnt           <= data_cnt +1'b1;
				s_axis_s2mm_tlast  <= 1'b0;
			end
		end
		StopDATA1:
		begin
			s_axis_s2mm_tvalid 	   <= 1'b0;
			data_cnt			   <= data_cnt;
			s_axis_s2mm_tdata      <= 256'b0;
		end
		StopDATA2:
		begin
			s_axis_s2mm_tvalid 	   <= 1'b0;
			data_cnt			   <= data_cnt;
			s_axis_s2mm_tdata      <= 256'b0;
		end

		default:
		begin
			s_axis_s2mm_tvalid     <= 1'b0;
		    s_axis_s2mm_tdata      <= 256'b0;
		    s_axis_s2mm_cmd_tvalid <= 1'b0;
		    s_axis_s2mm_cmd_tdata  <= 104'b0;
		    data_cnt               <= 5'd0;
        end
		endcase
	end
end

endmodule