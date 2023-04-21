import Vector::*;

typedef Bit#(26) LineAddr;
typedef Bit#(4) CacheBlockOffset;
typedef Bit#(7) CacheIndex;
typedef Bit#(19) CacheTag;
typedef Bit#(32) WordAddr;

typedef Bit#(32) Word;

typedef Vector#(16, Word) CacheLine;

typedef struct { Bool write; LineAddr addr; CacheLine data; } MainMemReq deriving (Eq, FShow, Bits, Bounded);

typedef struct { Bit#(4) byte_en; Bit#(32) addr; Word data; } CacheReq deriving (Eq, FShow, Bits);
