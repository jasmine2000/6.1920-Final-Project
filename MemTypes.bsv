typedef Bit#(26) LineAddr;

//  Changed from 512 to 32 (so that it is just one word)
typedef Bit#(32) MainMemResp;

typedef Bit#(32) Word;

typedef struct { Bit#(1) write; LineAddr addr; Bit#(512) MainMemResp; } MainMemReq deriving (Eq, FShow, Bits, Bounded);
