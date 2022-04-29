# Reference https://rosettacode.org/wiki/Pseudo-random_numbers/Xorshift_star#Ruby
class XorshiftService
  MASK64 = (1 << 64) - 1
  MASK32 = (1 << 32) - 1
 
  def initialize(seed = nil)
    seed ||= Random.new_seed
    @state = seed & MASK64
  end
 
  def next_int
    x = @state
    x =  x ^ (x >> 12)
    x = (x ^ (x << 25)) & MASK64
    x =  x ^ (x >> 27)

    @state = x

    (((x * 0x2545F4914F6CDD1D) & MASK64) >> 32) & MASK32
  end
 
  def next_float
    next_int.fdiv((1 << 32))
  end
end
