import Vector::*;

typedef Bit#(26) LineAddr;
typedef Bit#(4) CacheBlockOffset;
<<<<<<< HEAD
typedef Bit#(4) CacheIndex;
typedef Bit#(22) CacheTag;
=======
typedef Bit#(5) CacheIndex;
typedef Bit#(21) CacheTag;
>>>>>>> 4way set associative no replacement policy
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
<<<<<<< HEAD
      tag: address[31:10],
      index: address[9:6],
=======
      tag: address[31:11],
      index: address[10:6],
>>>>>>> 4way set associative no replacement policy
      blockOffset: address[5:2]
    };
endfunction