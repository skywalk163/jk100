fn get_h0(i : Int) -> Int {
  match i {
    0 => 0x6a09e667
    1 => 0xbb67ae85
    2 => 0x3c6ef372
    3 => 0xa54ff53a
    4 => 0x510e527f
    5 => 0x9b05688c
    6 => 0x1f83d9ab
    7 => 0x5be0cd19
    _ => 0
  }
}

fn get_k(i : Int) -> Int {
  match i {
    0 => 0x428a2f98
    1 => 0x71374491
    2 => 0xb5c0fbcf
    3 => 0xe9b5dba5
    4 => 0x3956c25b
    5 => 0x59f111f1
    6 => 0x923f82a4
    7 => 0xab1c5ed5
    8 => 0xd807aa98
    9 => 0x12835b01
    10 => 0x243185be
    11 => 0x550c7dc3
    12 => 0x72be5d74
    13 => 0x80deb1fe
    14 => 0x9bdc06a7
    15 => 0xc19bf174
    16 => 0xe49b69c1
    17 => 0xefbe4786
    18 => 0x0fc19dc6
    19 => 0x240ca1cc
    20 => 0x2de92c6f
    21 => 0x4a7484aa
    22 => 0x5cb0a9dc
    23 => 0x76f988da
    24 => 0x983e5152
    25 => 0xa831c66d
    26 => 0xb00327c8
    27 => 0xbf597fc7
    28 => 0xc6e00bf3
    29 => 0xd5a79147
    30 => 0x06ca6351
    31 => 0x14292967
    32 => 0x27b70a85
    33 => 0x2e1b2138
    34 => 0x4d2c6dfc
    35 => 0x53380d13
    36 => 0x650a7354
    37 => 0x766a0abb
    38 => 0x81c2c92e
    39 => 0x92722c85
    40 => 0xa2bfe8a1
    41 => 0xa81a664b
    42 => 0xc24b8b70
    43 => 0xc76c51a3
    44 => 0xd192e819
    45 => 0xd6990624
    46 => 0xf40e3585
    47 => 0x106aa070
    48 => 0x19a4c116
    49 => 0x1e376c08
    50 => 0x2748774c
    51 => 0x34b0bcb5
    52 => 0x391c0cb3
    53 => 0x4ed8aa4a
    54 => 0x5b9cca4f
    55 => 0x682e6ff3
    56 => 0x748f82ee
    57 => 0x78a5636f
    58 => 0x84c87814
    59 => 0x8cc70208
    60 => 0x90befffa
    61 => 0xa4506ceb
    62 => 0xbef9a3f7
    63 => 0xc67178f2
    _ => 0
  }
}

fn rotr(x : Int, n : Int) -> Int {
  (x >> n) | (x << (32 - n))
}

fn ch(x : Int, y : Int, z : Int) -> Int {
  (x & y) ^ ((0xFFFF_FFFF ^ x) & z)
}

fn maj(x : Int, y : Int, z : Int) -> Int {
  (x & y) ^ (x & z) ^ (y & z)
}

fn sigma0(x : Int) -> Int {
  rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22)
}

fn sigma1(x : Int) -> Int {
  rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25)
}

fn gamma0(x : Int) -> Int {
  rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3)
}

fn gamma1(x : Int) -> Int {
  rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10)
}

fn sha256_compress(h : FixedArray[Int], block : FixedArray[Int]) -> FixedArray[Int] {
  let w : FixedArray[Int] = FixedArray::make(64, 0)
  for i in 0..<16 {
    w[i] = block[i]
  }
  for i in 16..<64 {
    w[i] = gamma1(w[i - 2]) + w[i - 7] + gamma0(w[i - 15]) + w[i - 16]
  }
  let mut a = h[0]
  let mut b = h[1]
  let mut c = h[2]
  let mut d = h[3]
  let mut e = h[4]
  let mut f = h[5]
  let mut g = h[6]
  let mut hh = h[7]
  for i in 0..<64 {
    let t1 = hh + sigma1(e) + ch(e, f, g) + get_k(i) + w[i]
    let t2 = sigma0(a) + maj(a, b, c)
    hh = g
    g = f
    f = e
    e = d + t1
    d = c
    c = b
    b = a
    a = t1 + t2
  }
  let result : FixedArray[Int] = FixedArray::make(8, 0)
  result[0] = h[0] + a
  result[1] = h[1] + b
  result[2] = h[2] + c
  result[3] = h[3] + d
  result[4] = h[4] + e
  result[5] = h[5] + f
  result[6] = h[6] + g
  result[7] = h[7] + hh
  result
}

fn sha256_hex(data : Bytes) -> String {
  let len = data.length()
  let bit_len = len * 8
  let mut padded_len = len + 1
  while (padded_len % 64) != 56 {
    padded_len = padded_len + 1
  }
  padded_len = padded_len + 8
  let padded : FixedArray[Byte] = FixedArray::make(padded_len, 0)
  for i in 0..<len {
    padded[i] = data[i]
  }
  padded[len] = 0x80
  let length_offset = padded_len - 8
  let bit_len_i = bit_len
  padded[length_offset] = ((bit_len_i >> 56) & 0xFF).to_byte()
  padded[length_offset + 1] = ((bit_len_i >> 48) & 0xFF).to_byte()
  padded[length_offset + 2] = ((bit_len_i >> 40) & 0xFF).to_byte()
  padded[length_offset + 3] = ((bit_len_i >> 32) & 0xFF).to_byte()
  padded[length_offset + 4] = ((bit_len_i >> 24) & 0xFF).to_byte()
  padded[length_offset + 5] = ((bit_len_i >> 16) & 0xFF).to_byte()
  padded[length_offset + 6] = ((bit_len_i >> 8) & 0xFF).to_byte()
  padded[length_offset + 7] = (bit_len_i & 0xFF).to_byte()
  let h : FixedArray[Int] = FixedArray::make(8, 0)
  for i in 0..<8 {
    h[i] = get_h0(i)
  }
  let num_blocks = padded_len / 64
  for block_idx in 0..<num_blocks {
    let block : FixedArray[Int] = FixedArray::make(16, 0)
    for i in 0..<16 {
      let offset = block_idx * 64 + i * 4
      let b0 = padded[offset].to_int()
      let b1 = padded[offset + 1].to_int()
      let b2 = padded[offset + 2].to_int()
      let b3 = padded[offset + 3].to_int()
      let value = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
      block[i] = value
    }
    let new_h = sha256_compress(h, block)
    for i in 0..<8 {
      h[i] = new_h[i]
    }
  }
  let mut result = ""
  for i in 0..<8 {
    result = result + int_to_hex(h[i])
  }
  result
}

fn int_to_hex(v : Int) -> String {
  let hex_chars = "0123456789abcdef"
  let mut s = ""
  for i in 0..<8 {
    let shift = (7 - i) * 4
    let nibble_val = (v >> shift) & 0xF
    let nibble_char = String::make(1, hex_chars[nibble_val].unsafe_to_char())
    s = s + nibble_char
  }
  s
}

pub fn bytes_sha256(data : Bytes) -> String {
  sha256_hex(data)
}