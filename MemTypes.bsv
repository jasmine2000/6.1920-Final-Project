import Vector::*;

typedef Bit#(26) LineAddr;
typedef Bit#(4) CacheBlockOffset;
typedef Bit#(2) CacheIndex;
typedef Bit#(24) CacheTag;
typedef Bit#(32) WordAddr;

typedef Bit#(32) Word;
typedef struct { Word i1; Maybe#(Word) i2; } ICacheResp deriving (Eq, FShow, Bits);

typedef Vector#(16, Word) CacheLine;

typedef struct { Bool write; LineAddr addr; CacheLine data; } MainMemReq deriving (Eq, FShow, Bits, Bounded);

typedef struct { Bit#(4) byte_en; Bit#(32) addr; Word data; } CacheReq deriving (Eq, FShow, Bits, Bounded);

typedef struct {
    CacheTag tag;
    CacheIndex index;
    CacheBlockOffset blockOffset;
} Address deriving (FShow);

function Address getAddressFields(WordAddr address);
    return Address {
      tag: address[31:8],
      index: address[7:6],
      blockOffset: address[5:2]
    };
endfunction