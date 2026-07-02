module keccak_top
#(
    parameter N = 64,
    parameter IN_BUF_SIZE = 200,
    parameter OUT_BUF_SIZE = 200
)
(
    input wire                        Clock,
    input wire                        Reset,
    input wire                        Start,
    input wire  [200*8-1:0]           Din,
    input wire                        Req_more,

    output  reg                       Ready,
    output  wire [200*8-1:0]          Dout
);


reg  [4:0]      round_cnt;              // index of the round applied this cycle (0..23)
wire [1599:0]   swap_data_in;           // byte-swapped Din (byte stream -> lanes)
wire [1599:0]   swap_data_out;          // byte-swapped state (lanes -> byte stream)
wire [1599:0]   keccak_state;           // registered permutation state (inside keccak_f)
wire [1599:0]   round_state_in;         // round input: fresh block on Start, feedback otherwise
reg  [63:0]     round_constant;         // RC[round_cnt]

wire            trigger;                // begin a permutation (Start absorb or Req_more squeeze)
wire            active;                 // keccak_f enable: run a round this cycle

assign trigger = (Start | Req_more) & Ready;
assign active  = ~Ready | trigger;      // busy cycles + the trigger cycle (round 0)


//Swapped input endiannes, byte streams to 64 bit data (one lane per line)
assign swap_data_in[63:0]      = {Din[7:0], Din[15:8], Din[23:16], Din[31:24], Din[39:32], Din[47:40], Din[55:48], Din[63:56]};
assign swap_data_in[127:64]    = {Din[71:64], Din[79:72], Din[87:80], Din[95:88], Din[103:96], Din[111:104], Din[119:112], Din[127:120]};
assign swap_data_in[191:128]   = {Din[135:128], Din[143:136], Din[151:144], Din[159:152], Din[167:160], Din[175:168], Din[183:176], Din[191:184]};
assign swap_data_in[255:192]   = {Din[199:192], Din[207:200], Din[215:208], Din[223:216], Din[231:224], Din[239:232], Din[247:240], Din[255:248]};
assign swap_data_in[319:256]   = {Din[263:256], Din[271:264], Din[279:272], Din[287:280], Din[295:288], Din[303:296], Din[311:304], Din[319:312]};
assign swap_data_in[383:320]   = {Din[327:320], Din[335:328], Din[343:336], Din[351:344], Din[359:352], Din[367:360], Din[375:368], Din[383:376]};
assign swap_data_in[447:384]   = {Din[391:384], Din[399:392], Din[407:400], Din[415:408], Din[423:416], Din[431:424], Din[439:432], Din[447:440]};
assign swap_data_in[511:448]   = {Din[455:448], Din[463:456], Din[471:464], Din[479:472], Din[487:480], Din[495:488], Din[503:496], Din[511:504]};
assign swap_data_in[575:512]   = {Din[519:512], Din[527:520], Din[535:528], Din[543:536], Din[551:544], Din[559:552], Din[567:560], Din[575:568]};
assign swap_data_in[639:576]   = {Din[583:576], Din[591:584], Din[599:592], Din[607:600], Din[615:608], Din[623:616], Din[631:624], Din[639:632]};
assign swap_data_in[703:640]   = {Din[647:640], Din[655:648], Din[663:656], Din[671:664], Din[679:672], Din[687:680], Din[695:688], Din[703:696]};
assign swap_data_in[767:704]   = {Din[711:704], Din[719:712], Din[727:720], Din[735:728], Din[743:736], Din[751:744], Din[759:752], Din[767:760]};
assign swap_data_in[831:768]   = {Din[775:768], Din[783:776], Din[791:784], Din[799:792], Din[807:800], Din[815:808], Din[823:816], Din[831:824]};
assign swap_data_in[895:832]   = {Din[839:832], Din[847:840], Din[855:848], Din[863:856], Din[871:864], Din[879:872], Din[887:880], Din[895:888]};
assign swap_data_in[959:896]   = {Din[903:896], Din[911:904], Din[919:912], Din[927:920], Din[935:928], Din[943:936], Din[951:944], Din[959:952]};
assign swap_data_in[1023:960]  = {Din[967:960], Din[975:968], Din[983:976], Din[991:984], Din[999:992], Din[1007:1000], Din[1015:1008], Din[1023:1016]};
assign swap_data_in[1087:1024] = {Din[1031:1024], Din[1039:1032], Din[1047:1040], Din[1055:1048], Din[1063:1056], Din[1071:1064], Din[1079:1072], Din[1087:1080]};
assign swap_data_in[1151:1088] = {Din[1095:1088], Din[1103:1096], Din[1111:1104], Din[1119:1112], Din[1127:1120], Din[1135:1128], Din[1143:1136], Din[1151:1144]};
assign swap_data_in[1215:1152] = {Din[1159:1152], Din[1167:1160], Din[1175:1168], Din[1183:1176], Din[1191:1184], Din[1199:1192], Din[1207:1200], Din[1215:1208]};
assign swap_data_in[1279:1216] = {Din[1223:1216], Din[1231:1224], Din[1239:1232], Din[1247:1240], Din[1255:1248], Din[1263:1256], Din[1271:1264], Din[1279:1272]};
assign swap_data_in[1343:1280] = {Din[1287:1280], Din[1295:1288], Din[1303:1296], Din[1311:1304], Din[1319:1312], Din[1327:1320], Din[1335:1328], Din[1343:1336]};
assign swap_data_in[1407:1344] = {Din[1351:1344], Din[1359:1352], Din[1367:1360], Din[1375:1368], Din[1383:1376], Din[1391:1384], Din[1399:1392], Din[1407:1400]};
assign swap_data_in[1471:1408] = {Din[1415:1408], Din[1423:1416], Din[1431:1424], Din[1439:1432], Din[1447:1440], Din[1455:1448], Din[1463:1456], Din[1471:1464]};
assign swap_data_in[1535:1472] = {Din[1479:1472], Din[1487:1480], Din[1495:1488], Din[1503:1496], Din[1511:1504], Din[1519:1512], Din[1527:1520], Din[1535:1528]};
assign swap_data_in[1599:1536] = {Din[1543:1536], Din[1551:1544], Din[1559:1552], Din[1567:1560], Din[1575:1568], Din[1583:1576], Din[1591:1584], Din[1599:1592]};


assign round_state_in = (trigger & Start) ? swap_data_in : keccak_state;


//Round constants (standard Keccak-f[1600], identical to keccak_round_constants_gen)
always @(*)
begin
    case(round_cnt)
        5'd0  : round_constant = 64'h0000000000000001;
        5'd1  : round_constant = 64'h0000000000008082;
        5'd2  : round_constant = 64'h800000000000808A;
        5'd3  : round_constant = 64'h8000000080008000;
        5'd4  : round_constant = 64'h000000000000808B;
        5'd5  : round_constant = 64'h0000000080000001;
        5'd6  : round_constant = 64'h8000000080008081;
        5'd7  : round_constant = 64'h8000000000008009;
        5'd8  : round_constant = 64'h000000000000008A;
        5'd9  : round_constant = 64'h0000000000000088;
        5'd10 : round_constant = 64'h0000000080008009;
        5'd11 : round_constant = 64'h000000008000000A;
        5'd12 : round_constant = 64'h000000008000808B;
        5'd13 : round_constant = 64'h800000000000008B;
        5'd14 : round_constant = 64'h8000000000008089;
        5'd15 : round_constant = 64'h8000000000008003;
        5'd16 : round_constant = 64'h8000000000008002;
        5'd17 : round_constant = 64'h8000000000000080;
        5'd18 : round_constant = 64'h000000000000800A;
        5'd19 : round_constant = 64'h800000008000000A;
        5'd20 : round_constant = 64'h8000000080008081;
        5'd21 : round_constant = 64'h8000000000008080;
        5'd22 : round_constant = 64'h0000000080000001;
        5'd23 : round_constant = 64'h8000000080008008;
        default: round_constant = 64'h0000000000000000;
    endcase
end


keccak_f keccak_core
    (
    .iClk    (Clock          ),
    .iClear  (Reset          ),
    .iActive (active         ),
    .iState  (round_state_in ),
    .iRC     (round_constant ),
    .oState  (keccak_state   )
    );


always @ (posedge Clock) begin
    if(Reset) begin
        round_cnt <= 5'd0;
        Ready     <= 1'b1;
    end else if(trigger) begin
        round_cnt <= 5'd1;
        Ready     <= 1'b0;
    end else if(~Ready) begin
        if(round_cnt == 5'd23) begin
            round_cnt <= 5'd0;
            Ready     <= 1'b1;
        end else begin
            round_cnt <= round_cnt + 5'd1;
        end
    end
end


//Swapped output endiannes, 64 bit data to byte streams (one lane per line)
assign swap_data_out[63:0]      = {keccak_state[7:0], keccak_state[15:8], keccak_state[23:16], keccak_state[31:24], keccak_state[39:32], keccak_state[47:40], keccak_state[55:48], keccak_state[63:56]};
assign swap_data_out[127:64]    = {keccak_state[71:64], keccak_state[79:72], keccak_state[87:80], keccak_state[95:88], keccak_state[103:96], keccak_state[111:104], keccak_state[119:112], keccak_state[127:120]};
assign swap_data_out[191:128]   = {keccak_state[135:128], keccak_state[143:136], keccak_state[151:144], keccak_state[159:152], keccak_state[167:160], keccak_state[175:168], keccak_state[183:176], keccak_state[191:184]};
assign swap_data_out[255:192]   = {keccak_state[199:192], keccak_state[207:200], keccak_state[215:208], keccak_state[223:216], keccak_state[231:224], keccak_state[239:232], keccak_state[247:240], keccak_state[255:248]};
assign swap_data_out[319:256]   = {keccak_state[263:256], keccak_state[271:264], keccak_state[279:272], keccak_state[287:280], keccak_state[295:288], keccak_state[303:296], keccak_state[311:304], keccak_state[319:312]};
assign swap_data_out[383:320]   = {keccak_state[327:320], keccak_state[335:328], keccak_state[343:336], keccak_state[351:344], keccak_state[359:352], keccak_state[367:360], keccak_state[375:368], keccak_state[383:376]};
assign swap_data_out[447:384]   = {keccak_state[391:384], keccak_state[399:392], keccak_state[407:400], keccak_state[415:408], keccak_state[423:416], keccak_state[431:424], keccak_state[439:432], keccak_state[447:440]};
assign swap_data_out[511:448]   = {keccak_state[455:448], keccak_state[463:456], keccak_state[471:464], keccak_state[479:472], keccak_state[487:480], keccak_state[495:488], keccak_state[503:496], keccak_state[511:504]};
assign swap_data_out[575:512]   = {keccak_state[519:512], keccak_state[527:520], keccak_state[535:528], keccak_state[543:536], keccak_state[551:544], keccak_state[559:552], keccak_state[567:560], keccak_state[575:568]};
assign swap_data_out[639:576]   = {keccak_state[583:576], keccak_state[591:584], keccak_state[599:592], keccak_state[607:600], keccak_state[615:608], keccak_state[623:616], keccak_state[631:624], keccak_state[639:632]};
assign swap_data_out[703:640]   = {keccak_state[647:640], keccak_state[655:648], keccak_state[663:656], keccak_state[671:664], keccak_state[679:672], keccak_state[687:680], keccak_state[695:688], keccak_state[703:696]};
assign swap_data_out[767:704]   = {keccak_state[711:704], keccak_state[719:712], keccak_state[727:720], keccak_state[735:728], keccak_state[743:736], keccak_state[751:744], keccak_state[759:752], keccak_state[767:760]};
assign swap_data_out[831:768]   = {keccak_state[775:768], keccak_state[783:776], keccak_state[791:784], keccak_state[799:792], keccak_state[807:800], keccak_state[815:808], keccak_state[823:816], keccak_state[831:824]};
assign swap_data_out[895:832]   = {keccak_state[839:832], keccak_state[847:840], keccak_state[855:848], keccak_state[863:856], keccak_state[871:864], keccak_state[879:872], keccak_state[887:880], keccak_state[895:888]};
assign swap_data_out[959:896]   = {keccak_state[903:896], keccak_state[911:904], keccak_state[919:912], keccak_state[927:920], keccak_state[935:928], keccak_state[943:936], keccak_state[951:944], keccak_state[959:952]};
assign swap_data_out[1023:960]  = {keccak_state[967:960], keccak_state[975:968], keccak_state[983:976], keccak_state[991:984], keccak_state[999:992], keccak_state[1007:1000], keccak_state[1015:1008], keccak_state[1023:1016]};
assign swap_data_out[1087:1024] = {keccak_state[1031:1024], keccak_state[1039:1032], keccak_state[1047:1040], keccak_state[1055:1048], keccak_state[1063:1056], keccak_state[1071:1064], keccak_state[1079:1072], keccak_state[1087:1080]};
assign swap_data_out[1151:1088] = {keccak_state[1095:1088], keccak_state[1103:1096], keccak_state[1111:1104], keccak_state[1119:1112], keccak_state[1127:1120], keccak_state[1135:1128], keccak_state[1143:1136], keccak_state[1151:1144]};
assign swap_data_out[1215:1152] = {keccak_state[1159:1152], keccak_state[1167:1160], keccak_state[1175:1168], keccak_state[1183:1176], keccak_state[1191:1184], keccak_state[1199:1192], keccak_state[1207:1200], keccak_state[1215:1208]};
assign swap_data_out[1279:1216] = {keccak_state[1223:1216], keccak_state[1231:1224], keccak_state[1239:1232], keccak_state[1247:1240], keccak_state[1255:1248], keccak_state[1263:1256], keccak_state[1271:1264], keccak_state[1279:1272]};
assign swap_data_out[1343:1280] = {keccak_state[1287:1280], keccak_state[1295:1288], keccak_state[1303:1296], keccak_state[1311:1304], keccak_state[1319:1312], keccak_state[1327:1320], keccak_state[1335:1328], keccak_state[1343:1336]};
assign swap_data_out[1407:1344] = {keccak_state[1351:1344], keccak_state[1359:1352], keccak_state[1367:1360], keccak_state[1375:1368], keccak_state[1383:1376], keccak_state[1391:1384], keccak_state[1399:1392], keccak_state[1407:1400]};
assign swap_data_out[1471:1408] = {keccak_state[1415:1408], keccak_state[1423:1416], keccak_state[1431:1424], keccak_state[1439:1432], keccak_state[1447:1440], keccak_state[1455:1448], keccak_state[1463:1456], keccak_state[1471:1464]};
assign swap_data_out[1535:1472] = {keccak_state[1479:1472], keccak_state[1487:1480], keccak_state[1495:1488], keccak_state[1503:1496], keccak_state[1511:1504], keccak_state[1519:1512], keccak_state[1527:1520], keccak_state[1535:1528]};
assign swap_data_out[1599:1536] = {keccak_state[1543:1536], keccak_state[1551:1544], keccak_state[1559:1552], keccak_state[1567:1560], keccak_state[1575:1568], keccak_state[1583:1576], keccak_state[1591:1584], keccak_state[1599:1592]};

assign Dout = swap_data_out;


endmodule
