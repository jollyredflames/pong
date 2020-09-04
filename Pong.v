`include "PS2_Keyboard_Controller.v"

module Pong
	(
		CLOCK_50,						//	On Board 50 MHz
      KEY,
      SW,
		PS2_CLK,
		PS2_DAT,
		// The ports below are for the VGA output.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B,   						//	VGA Blue[9:0]
		HEX0,
		HEX3,
		HEX2,
		HEX5,
		LEDR
	);

	input	CLOCK_50;	//	50 MHz
	input   [9:0]   SW;
	input   [3:0]   KEY;
	inout PS2_CLK;
	inout PS2_DAT;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output	VGA_CLK;   					//	VGA Clock
	output	VGA_HS;						//	VGA H_SYNC
	output	VGA_VS;						//	VGA V_SYNC
	output	VGA_BLANK_N;					//	VGA BLANK
	output	VGA_SYNC_N;					//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	output   [6:0] HEX0;
	output   [6:0] HEX3;
	output   [6:0] HEX2;
	output   [6:0] HEX5;
	output	[9:0] LEDR;
	
	wire resetn;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	reg [2:0] colour;
	reg [7:0] x;
	reg [6:0] y;
	wire writeEn;
	
	// Wires representing direct output from the keyboard controller.
	 wire w_pulse,
	      a_pulse,
			s_pulse,
			d_pulse,
			left_pulse,
			right_pulse,
			up_pulse,
			down_pulse,
			space_pulse,
			enter_pulse;
	wire [7:0] game_x, end_x;
	wire [6:0] game_y, end_y;
	wire [2:0] game_clr, end_clr;
	wire game_over, new_game, erase;
	wire [1:0] winner;
	//reg [1:0] p1setScore = 2'b00;
	//reg [1:0] p2setScore = 2'b00;

	// Create an Instance of a  controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
	
	keyboard_tracker #(.PULSE_OR_HOLD(0)) keyboard_signal(
	     .clock(CLOCK_50),
		  .reset(resetn),
		  .PS2_CLK(PS2_CLK),
		  .PS2_DAT(PS2_DAT),
		  .w(w_pulse),
		  .a(a_pulse),
		  .s(s_pulse),
		  .d(d_pulse),
		  .left(left_pulse),
		  .right(right_pulse),
		  .up(up_pulse),
		  .down(down_pulse),
		  .space(space_pulse),
		  .enter(enter_pulse));
    
    // Instansiate datapath
	datapath d0(
		.clk(CLOCK_50),
		.reset_n(resetn),
		.plot(writeEn),
		.p1up(w_pulse),
		.p1down(s_pulse),
		.p2up(up_pulse),
		.p2down(down_pulse),
		.ball_clr(SW[6:4]),
		.score1_out(HEX5),
		.score2_out(HEX0),
		.setp1Hex(HEX3),
		.setp2Hex(HEX2),
		.p1_clr(SW[9:7]),
		.p2_clr(SW[2:0]),
		.new_game(new_game),
		.x_out(game_x),
		.y_out(game_y),
		.clr_out(game_clr),
		.who_wonner(winner),
		.game_over(game_over));

    // Instansiate FSM control
    control c0(
		.clk(CLOCK_50),
		.reset_n(resetn),
		.go(enter_pulse),
		.game_over(game_over),
		.new_game(new_game),
		.erase(erase),
		.plot(writeEn));
		
	//decoder setP1Score(.S(4'hF), .HEX(HEX3));
	//decoder setP2Score(.S(4'hF), .HEX(HEX2));
		
	 draw_end_screen draw_end(
		.clk(CLOCK_50),
		.x(end_x),
		.y(end_y),
		.clr(end_clr),
		.erase(erase),
		.winner(winner));
	
	 always @ (posedge CLOCK_50) begin
		if (!game_over) begin
			x <= game_x;
			y <= game_y;
			colour <= game_clr;
		end
		else begin
			x <= end_x;
			y <= end_y;
			colour <= end_clr;
		end
	 end
	 
	 assign LEDR[9:0] = {10{game_over}};
    
endmodule

module datapath(
	input clk,
	input reset_n,
	input plot,
	input p1up,
	input p1down,
	input p2up,
	input p2down,
	input [2:0] ball_clr,
	input [2:0] p1_clr,
	input	[2:0] p2_clr,
	input new_game,
	output [7:0] x_out,
	output [6:0] y_out,
	output [2:0] clr_out,
	output [6:0] score1_out,
	output [6:0] score2_out,
	output [6:0] setp1Hex,
	output [6:0] setp2Hex,
	output [1:0] who_wonner,
	output reg game_over);

	//default value of who won is 0
	reg [1:0] who_won = 2'b00;
	
	reg [3:0] setp1 = 4'd0;
	reg [3:0] setp2 = 4'd0;
	// ball
	reg [7:0] x = 8'd80;
	reg [6:0] y = 7'd60;
	reg [7:0] old_x = 8'd80;
	reg [6:0] old_y = 7'd60;
	reg [2:0] clr;
	reg [1:0] q = 2'b00;
	reg [4:0] frame;
	reg [2:0] dir = 3'b000;
	reg done = 1'b0;
	reg count = 1'b1;
	reg draw = 1'b0;
	reg [19:0] Q;
	reg update = 1'b0;
	reg drawed =1'b0;
	reg [2:0] tmp = 3'b000;
	reg [2:0] tmp2 = 3'b000;
	reg [3:0] score1 = 4'd5;
	reg [3:0] score2 = 4'd5;
	
	//paddles
	reg [7:0] p1_x = 8'd0;
	reg [6:0] p1_y = 7'd55;
	reg [7:0] old_p1x = 8'd0;
	reg [6:0] old_p1y = 7'd55;
	reg [7:0] p2_x = 8'd156;
	reg [6:0] p2_y = 7'd55;
	reg [7:0] old_p2x = 8'd156;
	reg [6:0] old_p2y = 7'd55;
	
	reg p1_done = 0;
	reg p1_erased = 0;
	reg p2_done = 0;
	reg p2_erased = 0;
	reg ball_done =0;
	reg ball_erased = 0;
	reg [3:0] p1 = 4'b0000;
	reg [3:0] p2 = 4'b0000;
	
	reg [1:0] count2 = 2'b00;
	reg bounced = 1'b0;
	
	always @(posedge clk)
	begin
		if (!reset_n)
		begin
			x <= 8'b01001111;
			old_x <= 8'b01001111;
			y <= 7'b0111011;
			old_y <= 7'b0111011;
			clr <= 3'b111;
			q <= 2'b00;
			draw <= 1'b1;
			
			p1_x <= 8'd0;
			p1_y <= 7'd55;
			old_p1x <= 8'd0;
			old_p1y <= 7'd55;
	
			p2_x <= 8'd156;
			p2_y <= 7'd55;
			old_p2x <= 8'd156;
			old_p2y <= 7'd55;
			game_over <= 1'd0;
		end
		else begin
			// change to not game over after new game
			if (new_game)
				game_over = 1'b0;
			
			if (draw && plot) begin
				// draw ball
				if (q == 2'b11 && !ball_done) begin
					x <= old_x + {7'b0000000, q[0]};
					y <= old_y + {6'b000000, q[1]};
					q <= 2'b00;
					drawed <= 1'b1;
					clr <= ball_clr;
					ball_done <= 1;
					if (p1_done && p2_done) begin
						draw <= 1'b0;
					end
				end
				else if (q == 2'b00 && !ball_done) begin
					x <= old_x;
					y <= old_y;
					q <= q + 1'b1;
					clr <= ball_clr;
				end
				else if (!ball_done) begin	
					x <= old_x + {7'b0000000, q[0]};
					y <= old_y + {6'b000000, q[1]};
					clr <= ball_clr;
					q <= q + 1'b1;		
				end
			
				// drawing paddle 1
				if (drawed && !p1_done) begin
					if (p1 == 4'b1111) begin
						x <= old_p1x + {7'b0000000, p1[0]};
						y <= old_p1y + {4'b0000, p1[3:1]};
						p1 <= 4'b0000;
						p1_done <= 1'b1;
					end
					else if (p1 == 4'b0000) begin
						x <= old_p1x;
						y <= old_p1y;
						p1 <= p1 + 1'b1;
						clr <= p1_clr;
					end
					else begin
						x <= old_p1x + {7'b0000000, p1[0]};
						y <= old_p1y + {4'b0000, p1[3:1]};
						clr <= p1_clr;
						p1 <= p1 + 1'b1;
					end
				end
			
				// drawing paddle 2
				if (drawed && p1_done && !p2_done) begin
					if (p2 == 4'b1111) begin
						x <= old_p2x + {7'b0000000, p2[0]};
						y <= old_p2y + {4'b0000, p2[3:1]};
						p2 <= 4'b0000;
						p2_done <= 1'b1;
						draw <= 1'b0;
					end
					else if (p2 == 4'b0000) begin
						x <= old_p2x;
						y <= old_p2y;
						p2 <= p2 + 1'b1;
						clr <= p2_clr;
					end
					else begin
						x <= old_p2x + {7'b0000000, p2[0]};
						y <= old_p2y + {4'b0000, p2[3:1]};
						clr <= p2_clr;
						p2 <= p2 + 1'b1;
					end
				end
			end
	
			else if (plot && count == 1'b0 && drawed && tmp2 != 3'b111) begin 
				if (tmp2 == 3'b110) begin 
					drawed <= 1'b0;
				end
				else begin 
					tmp2 <= tmp2 + 1'b1;
				end 
			end
			
			// erasing
			else if (plot && (!draw && done && !update)) begin 
				if (q == 2'b11 && !ball_erased) begin
					x <= old_x + {7'b0000000, q[0]};
					y <= old_y + {6'b000000, q[1]};
					q <= 2'b00;
					ball_erased <= 1'b1;
					end
				else if (q == 2'b00 && !ball_erased) begin
					clr <= 3'b000;
					x <= old_x;
					y <= old_y;
					q <= q + 1;
				end
				else if (!ball_erased) begin 
					x <= old_x + {7'b0000000, q[0]};
					y <= old_y + {6'b000000, q[1]};
					clr <= 3'b000;
					q <= q + 1'b1;
				end 
				// erasing p1
				if (ball_erased && !p1_erased) begin
					if (p1 == 4'b1111) begin
						x <= old_p1x + {7'b0000000, p1[0]};
						y <= old_p1y + {4'b0000, p1[3:1]};
						p1 <= 4'b0000;
						p1_erased <= 1'b1;
					end
					else if (p1 == 4'b0000) begin
						x <= old_p1x;
						y <= old_p1y;
						p1 <= p1 + 1'b1;
						clr <= 3'b000;
					end else begin
						x <= old_p1x + {7'b0000000, p1[0]};
						y <= old_p1y + {4'b0000, p1[3:1]};
						clr <= 3'b000;
						p1 <= p1+1'b1;
					end
				end
				// erasing paddle 2
				if (p1_erased && !p2_erased) begin
					if (p2 == 4'b1111) begin
						x <= old_p2x + {7'b0000000, p2[0]};
						y <= old_p2y + {4'b0000, p2[3:1]};
						p2 <= 4'b0000;
						p2_erased <= 1'b1;
						draw <= 1'b0;
						update <= 1'b1;
					end
					else if (p2 == 4'b0000) begin
						x <= old_p2x;
						y <= old_p2y;
						p2 <= p2 + 1'b1;
						clr <= 3'b000;
					end else begin
						x <= old_p2x + {7'b0000000, p2[0]};
						y <= old_p2y + {4'b0000, p2[3:1]};
						clr <= 3'b000;
						p2 <= p2 + 1'b1;
					end
				end
			end
			
			else if (update && plot && tmp != 3'b111) begin 
				tmp <= tmp + 1'b1;
			end
			
			// ball collision
			else if (update && plot) begin
				if (old_x < 8'd1 || old_x > 8'd159) begin
					if (old_x < 8'd1 && score1 > 4'd0) begin
						score1 <= score1 - 1'b1;
					end
					else if (old_x < 8'd1 && score1 == 4'd0) begin
					//Player 2 has won
					   setp2 <= setp2 + 1'b1; 
						who_won <= 2'b10;
						score1 <= 4'd5;
						score2 <= 4'd5;
						old_p1y <= 7'd55;
						old_p2y <= 7'd55;
						game_over <= 1'd1;
					end
					else if (old_x > 8'd159 && score2 > 4'd0) begin
						score2 <= score2 - 1'b1;
					end
					else if (old_x > 8'd159 && score2 == 4'd0) begin
					//Player 1 has won
					   setp1 <= setp1 + 1'b1;
						who_won <= 2'b01;
						score2 <= 4'd5;
						score1 <= 4'd5;
						old_p1y <= 7'd55;
						old_p2y <= 7'd55;
						game_over <= 1'd1;
					end
					old_x <= 8'b01001111;
					old_y <= 7'b0111011;
					dir <= 3'b000;
				end
				
				// bounce
				else if ((old_y < 7'd1 || old_y > 7'd117)) begin 
					if ((dir == 3'b001) && !bounced) begin //CHANGE BACK TO 001 AFTER
						old_x <= old_x;
						old_y <= old_y +1;
						dir <= 3'b111;
						bounced <= 1'b1;
						end
					else if ((dir == 3'b111) && !bounced) begin 
						dir <= 3'b001;
						old_x <= old_x;
						old_y <= old_y - 1;
						bounced <= 1'b1;
						end
					else if ((dir == 3'b011) && !bounced) begin 
						dir <= 3'b101;
						old_x <= old_x;
						old_y <= old_y + 1;
						bounced <= 1'b1;
						end
					else if ((dir == 3'b101) && !bounced) begin
						dir <= 3'b011;
						old_x <= old_x;
						old_y <= old_y - 1;
						bounced <= 1'b1;
						end
					end
				
				// new coord when hit P1's paddle
				else if (old_x == 8'd2) begin 
					if (old_y > old_p1y - 1 && old_y < old_p1y + 8) begin
						if (old_p1y == old_y || old_p1y + 1 == old_y || old_p1y + 2 == old_y) begin
							dir <= 3'b011;
							old_x <= old_x + 1;
							old_y <= old_y - 1;
						end
						else if (old_p1y + 3 == old_y || old_p1y + 4 == old_y) begin
							dir <= 3'b100;
							old_x <= old_x + 1;
							old_y <= old_y;
						end
						else if (old_p1y + 5 == old_y || old_p1y + 6 == old_y || old_p1y +7 == old_y) begin
							dir <= 3'b101;
							old_x <= old_x + 1;
							old_y <= old_y + 1;
						end
					end
				end
				
				// new coord when hit P2's paddle
				else if (old_x == 8'd156) begin 
					if (old_y > old_p2y -1 && old_y < old_p2y+8) begin
						if (old_p2y == old_y || old_p2y+1 == old_y || old_p2y+2 == old_y) begin
							dir <= 3'b001;
							old_x <= old_x -1;
							old_y <= old_y -1;
						end
						else if (old_p2y + 3 == old_y || old_p2y + 4 == old_y) begin
							old_x <= old_x -1;
							old_y <= old_y;
							dir <= 3'b000;
						end
						else if (old_p2y + 5 == old_y || old_p2y + 6 == old_y || old_p2y +7 == old_y) begin
							dir <= 3'b111;
							old_x <= old_x -1;
							old_y <= old_y +1;
						end
					end
				end
				
				if (count2 != 2'b11) begin
					count2 <= count2 + 1'b1;
				end
				
				//West
				if (dir == 3'b000 && count2 == 2'b11) begin
					old_x <= old_x - 1'b1;
					old_y <= old_y;
					draw <= 1'b1; 
					update <= 1'b0;
					tmp <= 3'b0;
					ball_done <= 1'b0;
					p1_done <= 1'b0;
					p2_done <= 1'b0;
					ball_erased <= 1'b0;
					p1_erased <= 1'b0;
					p2_erased <= 1'b0;
					count2 <= 2'b00;
					bounced <= 1'b0;
					if (p2up == 1'b1 && old_p2y > 0) begin 
						old_p2y <= old_p2y - 1'b1;
					end
					if (p2down == 1'b1 && old_p2y < 7'd111) begin 
						old_p2y <= old_p2y + 1'b1;
					end
					if (p1up == 1'b1 && old_p1y > 0) begin 
						old_p1y <= old_p1y - 1'b1;
					end
					if (p1down == 1'b1 && old_p1y < 7'd111) begin 
						old_p1y <= old_p1y + 1'b1;
					end
				end
				
				// North West
				else if (dir == 3'b001 && count2 == 2'b11) begin
					old_x <= old_x - 1'b1;
					old_y <= old_y - 1'b1;
					draw <= 1'b1; 
					update <= 1'b0;
					tmp <= 3'b0;
					ball_done <= 1'b0;
					p1_done <= 1'b0;
					p2_done <= 1'b0;
					ball_erased <= 1'b0;
					p1_erased <= 1'b0;
					p2_erased <= 1'b0;
					count2 <= 2'b00;
					bounced <= 1'b0;
					if (p2up == 1'b1 && old_p2y > 0) begin 
						old_p2y <= old_p2y - 1'b1;
					end
					if (p2down == 1'b1 && old_p2y < 7'd112) begin 
						old_p2y <= old_p2y + 1'b1;
					end
					if (p1up == 1'b1 && old_p1y > 0) begin 
						old_p1y <= old_p1y - 1'b1;
					end
					if (p1down == 1'b1 && old_p1y < 7'd112) begin 
						old_p1y <= old_p1y + 1'b1;
					end	
				end
				

				
				// North East
				else if (dir == 3'b011 && count2 == 2'b11) begin
					old_x <= old_x + 1'b1;
					old_y <= old_y - 1'b1;
					draw <= 1'b1; 
					update <= 1'b0;
					tmp <= 3'b0;
					ball_done <= 1'b0;
					p1_done <= 1'b0;
					p2_done <= 1'b0;
					ball_erased <= 1'b0;
					p1_erased <= 1'b0;
					p2_erased <= 1'b0;
					count2 <= 2'b00;
					bounced <= 1'b0;
					if (p2up == 1'b1 && old_p2y > 0) begin 
						old_p2y <= old_p2y - 1'b1;
					end
					if (p2down == 1'b1 && old_p2y < 7'd112) begin 
						old_p2y <= old_p2y + 1'b1;
					end
					if (p1up == 1'b1 && old_p1y > 0) begin 
						old_p1y <= old_p1y - 1'b1;
					end
					if (p1down == 1'b1 && old_p1y < 7'd112) begin 
						old_p1y <= old_p1y + 1'b1;
					end	
				end
				
				// East
				else if (dir == 3'b100 && count2 == 2'b11) begin
					old_x <= old_x + 1'b1;
					old_y <= old_y;
					draw <= 1'b1; 
					update <= 1'b0;
					tmp <= 3'b0;
					ball_done <= 1'b0;
					p1_done <= 1'b0;
					p2_done <= 1'b0;
					ball_erased <= 1'b0;
					p1_erased <= 1'b0;
					p2_erased <= 1'b0;
					count2 <= 2'b00;
					bounced <= 1'b0;
					if (p2up == 1'b1 && old_p2y > 0) begin 
						old_p2y <= old_p2y - 1'b1;
					end
					if (p2down == 1'b1 && old_p2y < 7'd112) begin 
						old_p2y <= old_p2y + 1'b1;
					end
					if (p1up == 1'b1 && old_p1y > 0) begin 
						old_p1y <= old_p1y - 1'b1;
					end
					if (p1down == 1'b1 && old_p1y < 7'd112) begin 
						old_p1y <= old_p1y + 1'b1;
					end	
				end
				
				// South East
				else if (dir == 3'b101 && count2 == 2'b11) begin
					old_x <= old_x + 1'b1;
					old_y <= old_y + 1'b1;
					draw <= 1'b1; 
					update <= 1'b0;
					tmp <= 3'b0;
					ball_done <= 1'b0;
					p1_done <= 1'b0;
					p2_done <= 1'b0;
					ball_erased <= 1'b0;
					p1_erased <= 1'b0;
					p2_erased <= 1'b0;
					count2 <= 2'b00;
					bounced <= 1'b0;
					if (p2up == 1'b1 && old_p2y > 0) begin 
						old_p2y <= old_p2y - 1'b1;
					end
					if (p2down == 1'b1 && old_p2y < 7'd112) begin 
						old_p2y <= old_p2y + 1'b1;
					end
					if (p1up == 1'b1 && old_p1y > 0) begin 
						old_p1y <= old_p1y - 1'b1;
					end
					if (p1down == 1'b1 && old_p1y < 7'd112) begin 
						old_p1y <= old_p1y + 1'b1;
					end	
				end
				
				
				// South West
				else if (dir == 3'b111 && count2 == 2'b11) begin
					old_x <= old_x - 1'b1 ;
					old_y <= old_y + 1'b1;
					draw <= 1'b1; 
					update <= 1'b0;
					tmp <= 3'b0;
					p1_done <= 1'b0;
					p2_done <= 1'b0;
					ball_erased <= 1'b0;
					p1_erased <= 1'b0;
					p2_erased <= 1'b0;
					ball_done <= 1'b0;
					count2 <= 2'b00;
					bounced <= 1'b0;
					if (p2up == 1'b1 && old_p2y > 0) begin 
						old_p2y <= old_p2y - 1'b1;
					end
					if (p2down == 1'b1 && old_p2y < 7'd112) begin 
						old_p2y <= old_p2y + 1'b1;
					end
					if (p1up == 1'b1 && old_p1y > 0) begin 
						old_p1y <= old_p1y - 1'b1;
					end
					if (p1down == 1'b1 && old_p1y < 7'd112) begin 
						old_p1y <= old_p1y + 1'b1;
					end	
				end
		end
			
		else
			begin 
			x <= x;
			y <= y;
			old_x <= old_x;
			old_y <= old_y;
			end 
		end
	end 
	
	assign x_out = x;
	assign y_out = y;
	assign clr_out = clr;
	
	//assign speed
	always @(posedge clk)
	begin
		if (!reset_n) begin 
			Q <= 20'b00100001111010000111;
			frame <= 5'b00111;
		end 
		else if (plot && ((!draw && count) || update)) begin
			Q <= 20'b00100001111010000111;
			frame <= 5'b00111;
			if (drawed) begin
				count <= 1'b0;
			end
			if (update) begin 
				done <= 1'b0;
			end
		end
		else if(Q == 20'b00000000000000000000 && frame == 5'b00000) begin 
			Q <= 20'b00100001111010000111;
			frame <= 5'b00111;
			done <= 1'b1;
			count <= 1'b1;
		end
		else if(Q == 20'b00000000000000000000) begin
			Q <= 20'b00100001111010000111;
			frame <= frame - 1;
		end
		else begin
			Q <= Q - 1'b1;
		end
	end
	
	assign who_wonner = who_won;
	
	decoder d1(
		.S(score1),
		.HEX(score1_out));
	decoder d2(
		.S(score2),
		.HEX(score2_out));
	decoder d3(.S(setp1), .HEX(setp1Hex));
	decoder d4(.S(setp2), .HEX(setp2Hex));
		
endmodule

module control(
	input clk,
	input reset_n,
	input go,
	input game_over,
	output reg new_game,
	output reg erase,
	output reg plot);

	reg [2:0] current_state, next_state;

	localparam
		Wait = 3'd0,
		Start = 3'd1,
		End = 3'd2,
		End_wait = 3'd3;
		
	always @(*)
	begin 
		case (current_state)
		//Wait before start of game at a cleared screen
			Wait: next_state = go ? Start : Wait;
			Start: next_state = game_over ? End : Start;
		//End = Display who won
			End: next_state = go ? End_wait : End;
		//Clear who won here
			End_wait: next_state = go ? End_wait : Wait;
			default: next_state = Wait;
		endcase
	end

	always @(*)
	begin
		plot = 1'b0;
		new_game = 1'b0;
		erase = 1'b0;
		case (current_state)
			Wait:
				begin
				//Set new game to high to reset param game_over in datapath
					new_game = 1'b1;
				end
			Start:
				begin
					new_game = 1'b0;
					plot = 1'b1;
				end
			End: begin
				erase = 1'b0;
				plot = 1'b1;
			end
			End_wait: begin
			//Set erase on to make color black and go over "P2/P1" screen
				erase = 1'b1;
				plot = 1'b1;
			end
		endcase
	end

	always @(posedge clk)
	begin
		if (!reset_n) begin 
			current_state <= Wait;
		end
		else begin 
			current_state <= next_state;
		end
	end
endmodule




module decoder(HEX, S);
    input [3:0] S;
    output reg [6:0] HEX;
   
    always @(*)
        case (S)
            4'h0: HEX = 7'b100_0000;
            4'h1: HEX = 7'b111_1001;
            4'h2: HEX = 7'b010_0100;
            4'h3: HEX = 7'b011_0000;
            4'h4: HEX = 7'b001_1001;
            4'h5: HEX = 7'b001_0010;
            4'h6: HEX = 7'b000_0010;
            4'h7: HEX = 7'b111_1000;
            4'h8: HEX = 7'b000_0000;
            4'h9: HEX = 7'b001_1000;
            4'hA: HEX = 7'b000_1000;
            4'hB: HEX = 7'b000_0011;
            4'hC: HEX = 7'b100_0110;
            4'hD: HEX = 7'b010_0001;
            4'hE: HEX = 7'b000_0110;
				4'hF: HEX = 7'b000_1110;
            default: HEX = 7'h7f;
        endcase
endmodule

module draw_end_screen(clk, x, y, clr, winner, erase);
	input clk;
	input erase;
	output reg [7:0] x;
	output reg [6:0] y;
	output [2:0] clr;
	input [1:0] winner;
	reg [5:0] divider;
	reg [5:0] counter;
	reg [7:0] init_x = 8'd73;
	reg [6:0] init_y = 7'd58;
	
		// counter 6-bits 0-50
		always @(posedge clk) begin
		if (divider == 6'b111111) begin
			divider <= 6'd0;
			if (counter < 6'd50)
				counter <= counter + 1'b1;
			else
				counter <= 6'd0;
		end
		else
			divider <= divider + 1'b1;
	end
	
	// xy coord mux
		always @(*) begin
		if (winner == 2'b01) begin //Writes P1 in green to indicate that P1 has won
		case(counter)
			6'd0: begin
				x = init_x + 5'd0;
				y = init_y + 3'd0;
			end
			6'd1: begin
				x = init_x + 5'd1;
				y = init_y + 3'd0;
			end
			6'd2: begin
				x = init_x + 5'd2;
				y = init_y + 3'd0;
			end
			6'd3: begin
				x = init_x + 5'd2;
				y = init_y + 3'd1;
			end
			6'd4: begin
				x = init_x + 5'd2;
				y = init_y + 3'd2;
			end
			6'd5: begin
				x = init_x + 5'd1;
				y = init_y + 3'd2;
			end
			6'd6: begin
				x = init_x + 5'd0;
				y = init_y + 3'd2;
			end
			6'd7: begin
				x = init_x + 5'd0;
				y = init_y + 3'd1;
			end
			6'd8: begin
				x = init_x + 5'd0;
				y = init_y + 3'd3;
			end
			6'd9: begin
				x = init_x + 5'd0;
				y = init_y + 3'd4;
			end
			6'd10: begin
				x = init_x + 5'd4;
				y = init_y + 3'd0;
			end
			6'd13: begin
				x = init_x + 5'd4;
				y = init_y + 3'd1;
			end
			6'd14: begin
				x = init_x + 5'd4;
				y = init_y + 3'd2;
			end
			6'd16: begin
				x = init_x + 5'd4;
				y = init_y + 3'd3;
			end
			6'd17: begin
				x = init_x + 5'd4;
				y = init_y + 3'd4;
			end
			
			default: begin
				x = init_x + 5'd0;
				y = init_y + 3'd0;
			end
		endcase
		end
		else if (winner == 2'b10) begin //Writes P2 in green to indicate that P2 has won
		case(counter)
			6'd0: begin
				x = init_x + 5'd0;
				y = init_y + 3'd0;
			end
			6'd1: begin
				x = init_x + 5'd1;
				y = init_y + 3'd0;
			end
			6'd2: begin
				x = init_x + 5'd2;
				y = init_y + 3'd0;
			end
			6'd3: begin
				x = init_x + 5'd2;
				y = init_y + 3'd1;
			end
			6'd4: begin
				x = init_x + 5'd2;
				y = init_y + 3'd2;
			end
			6'd5: begin
				x = init_x + 5'd1;
				y = init_y + 3'd2;
			end
			6'd6: begin
				x = init_x + 5'd0;
				y = init_y + 3'd2;
			end
			6'd7: begin
				x = init_x + 5'd0;
				y = init_y + 3'd1;
			end
			6'd8: begin
				x = init_x + 5'd0;
				y = init_y + 3'd3;
			end
			6'd9: begin
				x = init_x + 5'd0;
				y = init_y + 3'd4;
			end
			6'd10: begin
				x = init_x + 5'd4;
				y = init_y + 3'd0;
			end
			6'd11: begin
				x = init_x + 5'd5;
				y = init_y + 3'd0;
			end
			6'd12: begin
				x = init_x + 5'd6;
				y = init_y + 3'd0;
			end
			6'd13: begin
				x = init_x + 5'd6;
				y = init_y + 3'd1;
			end
			6'd14: begin
				x = init_x + 5'd6;
				y = init_y + 3'd2;
			end
			6'd15: begin
				x = init_x + 5'd5;
				y = init_y + 3'd2;
			end
			6'd16: begin
				x = init_x + 5'd4;
				y = init_y + 3'd2;
			end
			6'd17: begin
				x = init_x + 5'd4;
				y = init_y + 3'd3;
			end
			6'd18: begin
				x = init_x + 5'd4;
				y = init_y + 3'd4;
			end
			6'd19: begin
				x = init_x + 5'd5;
				y = init_y + 3'd4;
			end
			6'd20: begin
				x = init_x + 5'd6;
				y = init_y + 3'd4;
			end	
			
			default: begin
				x = init_x + 5'd0;
				y = init_y + 3'd0;
			end
		endcase
		end
		else begin //Clears either P1 or P2 from the screen
		case(counter)
			6'd0: begin
				x = init_x + 5'd0;
				y = init_y + 3'd0;
			end
			6'd1: begin
				x = init_x + 5'd1;
				y = init_y + 3'd0;
			end
			6'd2: begin
				x = init_x + 5'd2;
				y = init_y + 3'd0;
			end
			6'd3: begin
				x = init_x + 5'd2;
				y = init_y + 3'd1;
			end
			6'd4: begin
				x = init_x + 5'd2;
				y = init_y + 3'd2;
			end
			6'd5: begin
				x = init_x + 5'd1;
				y = init_y + 3'd2;
			end
			6'd6: begin
				x = init_x + 5'd0;
				y = init_y + 3'd2;
			end
			6'd7: begin
				x = init_x + 5'd0;
				y = init_y + 3'd1;
			end
			6'd8: begin
				x = init_x + 5'd0;
				y = init_y + 3'd3;
			end
			6'd9: begin
				x = init_x + 5'd0;
				y = init_y + 3'd4;
			end
			6'd10: begin
				x = init_x + 5'd4;
				y = init_y + 3'd0;
			end
			6'd13: begin
				x = init_x + 5'd4;
				y = init_y + 3'd1;
			end
			6'd14: begin
				x = init_x + 5'd4;
				y = init_y + 3'd2;
			end
			6'd16: begin
				x = init_x + 5'd4;
				y = init_y + 3'd3;
			end
			6'd17: begin
				x = init_x + 5'd4;
				y = init_y + 3'd4;
			end
			
			6'd18: begin
				x = init_x + 5'd4;
				y = init_y + 3'd0;
			end
			6'd19: begin
				x = init_x + 5'd5;
				y = init_y + 3'd0;
			end
			6'd20: begin
				x = init_x + 5'd6;
				y = init_y + 3'd0;
			end
			6'd21: begin
				x = init_x + 5'd6;
				y = init_y + 3'd1;
			end
			6'd22: begin
				x = init_x + 5'd6;
				y = init_y + 3'd2;
			end
			6'd23: begin
				x = init_x + 5'd5;
				y = init_y + 3'd2;
			end
			6'd24: begin
				x = init_x + 5'd4;
				y = init_y + 3'd2;
			end
			6'd25: begin
				x = init_x + 5'd4;
				y = init_y + 3'd3;
			end
			6'd26: begin
				x = init_x + 5'd4;
				y = init_y + 3'd4;
			end
			6'd27: begin
				x = init_x + 5'd5;
				y = init_y + 3'd4;
			end
			6'd28: begin
				x = init_x + 5'd6;
				y = init_y + 3'd4;
			end
			
			default: begin
				x = init_x + 5'd0;
				y = init_y + 3'd0;
			end
		endcase
		end
	  end

	 
	
	
	assign clr = erase ? 3'b000 : 3'b010;
endmodule
