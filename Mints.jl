

module Mints

import FixedWidths

# Modulo ints intended for modelling hardware and computer arithmetic
# similar to Verilog arithmetic, and BitVector arithmetic

# unlike Bints, thereis no word growth when Mints are combined arithmetically
# the result type is the same as smallest Mint{N} argument (unlike Verilog)

# Signed or Unsigned?
#
# Question on whether the type should encode signedness - whether the underlying 
# integer represented is signed or unsigned.
# For an N-bit number, the number ranges are:
#    Unsigned:  0 .. 2^N-1
#    Signed:    -(2^(N-1)) .. 2^(N-1)-1
# The difference between these is the significance of the MSB
#    Unsigned:  +2^(N-1)
#    Signed:    -2^(N-1)
# ie they are the same Modulo 2^N

# Not convinced that there is any compelling argument to retain signedness as part of the number.
# The underlying operations are exactly the same.
# Unlike the Bint case, where the sign bit is important - eg any operation that requires 
# knowledge of the bits to the left of the MSB - eg right shifts, or fractional multiplication
# - this doesn't apply to Mints - the bits to the left of the MSB are explicitly unknown.

# If the signedness is retained - then when combining signed and unsigned, signed should win
# (which interestingly is the opposite of the choice that Verilog took)
# eg signed_Mint + 1 would still be signed

struct Mint{N} <: FixedWidths.FixedWidth
        n
        # make a new Mint, with random MSBs
        # it is fine for n to be out of range
        Mint{N}(n) where {N} = begin
                @assert N >= 0
                new{N}( xor( rand(typeof(n)) << N , n ) )
                # at some point in the fture, could just ignore the MSBs and not set them to rand()
                # this is just as an insurance check whilst the Mint implementation is new and largely untested 
        end
 
end

# type level:
Mint( ::Type{T} ) where { T <: FixedWidths.FixedWidth } = begin
        w = FixedWidths.num_bits_required( T )
        return Mint{w}
end
# value level:
Mint(n::T) where { T <: FixedWidths.FixedWidth } = begin
        w = FixedWidths.num_bits_required( T )
        return Mint{w}( Integer(n) )
end

# questionable whether Mint( Bint{-10,20} ) should return Mint{5} or Mint{6}


# truncate_lsbs should work for both positive and negative b
# (negative b is lossless)
FixedWidths.truncate_lsbs( n::Mint{N}, b ) where {N} = Mint{N-b}( n.n >> b )
FixedWidths.truncate_lsbs( ::Type{Mint{N}}, b ) where {N} = Mint{N-b}


FixedWidths.num_bits_required( ::Type{Mint{N}} ) where {N} = N
FixedWidths.left_shift( ::Type{Mint{N}}, b::Integer ) where {N} = begin
        @assert b >= 0
        Mint{N+b}
end 
FixedWidths.left_shift( n::Mint{N}, b::Integer ) where {N} = begin
        @assert b >= 0
        Mint{N+b}( n.n << b )
end


# the following allows arithmetic between Mint{N} and Bint{lo,hi} with result type Mint{N}
for op in ( :+, :-, :* ) eval( quote
        # type level:
        (Base.$op)( ::Type{Mint{N1}}, ::Type{Mint{N2}} ) where {N1,N2} = Mint{min(N1,N2)}
        (Base.$op)( ::Type{Mint{N1}}, ::Type{I }       ) where {N1, I<:Integer   } = Mint{    N1    }
        (Base.$op)( ::Type{I}       , ::Type{Mint{N2}} ) where { I<:Integer,   N2} = Mint{       N2 }
        # value level:
        (Base.$op)( a::Mint{N1}, b::Mint{N2} ) where {N1,N2} = Mint{min(N1,N2)}( (Base.$op)( a.n , b.n ) )
        (Base.$op)( a::Mint{N1}, b::I  ) where {N1, I<:Integer } = Mint{ N1 }(   (Base.$op)( a.n , b   ) )
        (Base.$op)( a::I , b::Mint{N2} ) where {I<:Integer, N2 } = Mint{ N2 }(   (Base.$op)( a   , b.n ) )
        end )
end

# extract the Mint as an Int value, assuming either unsigned, or signed:
Base.unsigned( n::Mint{N} ) where {N} = n.n & ~((~zero(n.n))<<N)
Base.signed(   n::Mint{N} ) where {N} = begin
        mask = ~((~zero(n.n)) << N)
        msbs = ( n.n >> (N-1) ) & 1 == 0 ? 0 : ~mask
        n1 = msbs | n.n & mask
        return n1
end

# extract the integer without the bounds:
(::Type{I})(n::Mint) where {I<:Unsigned} = Base.unsigned(n)
(::Type{I})(n::Mint) where {I<:Signed  } = Base.signed(n)
#Integer( n::Bint{lo,hi} ) where {lo,hi} = n.n
# convert to Float
(::Type{F})( n::Mint ) where {F<:AbstractFloat} = F( Base.signed(n) )




function Base.show(io::IO, x::Mint{N} ) where {N}
        print( io, "Mint{", N,"}( ", signed( unsigned(x) ), " )" )
end

# these act on types not values:
Base.zero( ::Type{Mint{N}} ) where {N} = Mint{N}(0)
Base.one(  ::Type{Mint{N}} ) where {N} = Mint{N}(1)

# because the MSBs of Mints are unknown, cannot compare Mints using <,<=,>,>=
# also, typemin or typemax don't always make sense for Mints
# especially when the signedness is not determined


Base.typemin( ::Type{Mint{N}} ) where {N} = Mint{N}
Base.typemax( ::Type{Mint{N}} ) where {N} = Mint{N}

#import Base.promote_rule
Base.promote_rule( ::Type{Mint{N1}} , ::Type{Mint{N2}} ) where {N1,N2} = Mint{min(N1,N2)}
Base.promote_rule( ::Type{Mint{N}} , ::Type{S} ) where {N,S} = Mint{N}


# unary negate
#import Base.-

function Base.:-( ::Type{Mint{N}} ) where {N}
        return Mint{N}
end

function Base.:-( n1::Mint{N} ) where {N}
        return (-Mint{N})( -n1.n )
end

# ones complement:
#import Base.~
function Base.:~( ::Type{Mint{N}} ) where {N}
        return Mint{N}
end
function Base.:~( n1::Mint{N} ) where {N}
        return (~Mint{N})( ~n1.n )
end


end # module
