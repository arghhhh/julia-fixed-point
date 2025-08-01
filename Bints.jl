

module Bints

# lo and hi are not checked for having the same type - could be different and should work

# see https://docs.julialang.org/en/v1/manual/types/#Primitive-Types-1
# see https://discourse.julialang.org/t/declaring-int256/29911

# LLVM can work on arbitrary fixed length bitvectors
# - so that could another approach to very large numbers
# At the moment, this code works for Int64, and should also work for Int128
# A big TODO is to make this work for arbitrary length integers - but this is not 
# immediately possible because of the Julia requirement that type parameters 
# be bitstypes.  One solution I've used to solve this is to make arbitrary length 
# integers be represented as tuples of bitstypes - like a very high radix notation

import FixedWidths

import BigIntBitsType

struct Bint{lo,hi,T} <: FixedWidths.FixedWidth
        n::T

        # make a Bint with a given range and value
#        function Bint(lo,hi, n::Integer )
#                # the following line enables n to be Mint and the appropriate signedness value to be extracted
#                n1 = lo < 0 ? Base.signed(n) : Base.unsigned(n)
#                if !( lo <= n1 <= hi )
#                        throw( OverflowError( "$n, $n1 out of range $(lo)..$(hi) ") )
#                end
#                T = promote_type( typeof(lo), typeof(hi) )
#                new{lo,hi,T}( T(n1) )
#        end

        # make a Bint from one with a narrower range
        function Bint{lo,hi,T}( n::Bint{n_lo,n_hi, n_T} ) where { lo, hi, T, n_lo, n_hi, n_T }
                # this is effectively a one-time type level check:
                if !( lo <= n_lo  && hi >= n_hi )
                        throw( OverflowError( "$n out of range $(lo)..$(hi) ") )
                end
              #  T = promote_type( typeof(lo), typeof(hi) )
                new{lo,hi,T}( T(n.n) )
        end     
        function Bint{lo,hi,T}( n::Integer )  where {lo,hi,T}
                #new{lo,hi,T}( T(n) )
                #return Bint(lo,hi,n)
                # the following line enables n to be Mint and the appropriate signedness value to be extracted
                n1 = lo < 0 ? Base.signed(n) : Base.unsigned(n)
                # this check is per value - so at run-time:
                if !( lo <= n1 <= hi )
                        throw( OverflowError( "$n, $n1 out of range $(lo)..$(hi) ") )
                end
            #    T = promote_type( typeof(lo), typeof(hi) )
                new{lo,hi,T}( T(n1) )
        end
        function Bint{lo,hi,T}( n::Integer, checked::Val{false} ) where {lo,hi,T}
          #      T = promote_type( typeof(lo), typeof(hi) )
                new{lo,hi,T}( n )
        end

end

# Bint(lo::BigInt,hi        ) = Bint{ BigIntBitsType.make_tuple_from_number(lo), hi }
# Bint(lo        ,hi::BigInt) = Bint{ lo, BigIntBitsType.make_tuple_from_number(hi) }
# Bint(lo::BigInt,hi::BigInt) = Bint{ BigIntBitsType.make_tuple_from_number(lo), BigIntBitsType.make_tuple_from_number(hi) }
#  

Bint( lo, hi ) = begin
        T = promote_type( typeof(lo), typeof(hi) )
        Bint{ lo, hi, T }  # TODO: for now only
end
Bint( n::Integer ) = Bint(n,n)( n, Val{false}() )


# truncate_lsbs should work for both positive and negative b
# (negative b is lossless)
FixedWidths.truncate_lsbs( n::Bint{lo,hi,T}, b ) where {lo,hi,T} = Bint(lo>>b,hi>>b)( n.n >> b )
FixedWidths.truncate_lsbs( ::Type{Bint{lo,hi,T}}, b ) where {lo,hi,T} = Bint(lo>>b,hi>>b)

# # lossless
# can have left shift because it should be lossless
# but don't have right shift because it would be lossy
# this function is used when adding fixpts with different exponents
function FixedWidths.left_shift( n1::Bint{lo,hi,T}, n2::Int64 ) where {lo,hi,T}

        # assuming that none of the following lines overflow

        @assert n2 >= 0 # must be lossless
        n = n1.n << n2

        lo1 = lo << n2
        hi1 = hi << n2
        return Bint(lo1,hi1)( n )
end
# typelevel:
function FixedWidths.left_shift( ::Type{T}, ::Type{Bint{e_lo,e_hi,e_T}} ) where {T<:Integer,e_lo,e_hi,e_T}
        return T  ## TODO: ???? is this used?
end
# typelevel:
function FixedWidths.left_shift( ::Type{Bint{lo,hi,T}}, e::Int ) where {lo,hi,T}
        # assuming that none of the following lines overflow
        @assert e >= 0  # must be lossless
        lo1 = lo << e
        hi1 = hi << e
        return Bint(lo1,hi1)
end
# typelevel:
function FixedWidths.left_shift( ::Type{Bint{lo,hi,T}}, ::Type{Bint{e_lo,e_hi,e_T}} ) where {lo,hi,T,e_lo,e_hi,e_T}
        # assuming that none of the following lines overflow
        @assert e_lo >= 0  # must be lossless
        lo1 = lo >= 0 ? lo << e_lo : lo << e_hi
        hi1 = hi >= 0 ? hi << e_hi : hi << e_lo
        return Bint(lo1,hi1)
end
function FixedWidths.left_shift( n1::Bint{lo,hi,T}, n2::Bint{e_lo,e_hi,e_T} ) where {lo,hi,T,e_lo,e_hi,e_T}
        # assuming that none of the following lines overflow
        n = n1.n << n2.n
        return FixedWidths.left_shift( Bint{lo,hi,T} , Bint{e_lo,e_hi,e_T} )(n,Val{false}() )
end

# add functionality expected of integers:

import Base.zero, Base.one
# these act on types not values:
Base.zero( ::Type{Bint{lo,hi,T}} ) where {lo,hi,T} = Bint(lo,hi)(0)
Base.one(  ::Type{Bint{lo,hi,T}} ) where {lo,hi,T} = Bint(lo,hi)(1)

import Base.typemin, Base.typemax
Base.typemin( ::Type{Bint{lo,hi,T}} ) where {lo,hi,T} = Bint(lo,hi)(lo)
Base.typemax( ::Type{Bint{lo,hi,T}} ) where {lo,hi,T} = Bint(lo,hi)(hi)

# # the next few lines allows comparisons with integers and allows clamp to work
# eg promote_type( Bints.uBint(4),  Int64 )
Base.promote_rule( ::Type{Bint{lo,hi,T1}} , ::Type{S} ) where {lo,hi,T1,S<:Integer} = begin
#        T = promote_type( typeof(lo), typeof(hi) )
        promote_type(T1,S)
end

Base.promote_rule( ::Type{Bint{lo1,hi1,T1}} , ::Type{Bint{lo2,hi2,T2}} ) where {lo1,hi1,T1,lo2,hi2,T2} = begin
        Bint( min(lo1,lo2), max(hi1,hi2) )
end


# extract the integer without the bounds:
# the following line was removed - it conflicts with Mint(n::Integer)
# - it seems safer to not to allow this, and use the Base.convert method instead
# (::Type{I})(n::Bint{lo,hi}) where {lo,hi,I<:Integer} = I(n.n)
Base.convert( ::Type{I}, n::Bint{lo,hi}) where {lo,hi,I<:Integer} = I(n.n)
Integer( n::Bint{lo,hi} ) where {lo,hi} = n.n
# convert to Float
(::Type{F})( n::Bint ) where {F<:AbstractFloat} = F( n.n )




# arithmetic:

function Base.:+( ::Type{Bint{lo1,hi1,T1}}, ::Type{Bint{lo2,hi2,T2}} ) where {lo1,hi1,T1,lo2,hi2,T2}
 
        lo = Base.Checked.checked_add( lo1, lo2)
        hi = Base.Checked.checked_add( hi1, hi2)

        return Bint( lo, hi )
end

function Base.:+( n1::Bint{lo1,hi1,T1}, n2::Bint{lo2,hi2,T2} ) where {lo1,hi1,T1,lo2,hi2,T2}
 
        # the expectation is that the above type level function is compiled to constants
        # and this entire function reduces to a single add without range checks

        return ( Bint{lo1,hi1,T1} + Bint{lo2,hi2,T2} )( n1.n + n2.n, Val{false}() )
end

function Base.:-( ::Type{Bint{lo1,hi1,T1}}, ::Type{Bint{lo2,hi2,T2}} ) where {lo1,hi1,T1,lo2,hi2,T2}
        lo = Base.Checked.checked_sub( lo1, hi2)
        hi = Base.Checked.checked_sub( hi1, lo2)
        return Bint( lo, hi )
end

function Base.:-( n1::Bint{lo1,hi1,T1}, n2::Bint{lo2,hi2,T2} ) where {lo1,hi1,T1,lo2,hi2,T2}
        return (Bint{lo1,hi1,T1} - Bint{lo2,hi2,T2})( n1.n - n2.n, Val{false}() )
end

function Base.:*( ::Type{Bint{lo1,hi1,T1}}, ::Type{Bint{lo2,hi2,T2}} ) where {lo1,hi1,T1,lo2,hi2,T2}
        y1 = Base.Checked.checked_mul( lo1, lo2)
        y2 = Base.Checked.checked_mul( lo1, hi2)
        y3 = Base.Checked.checked_mul( hi1, lo2)
        y4 = Base.Checked.checked_mul( hi1, hi2)

        lo = min( y1, y2, y3, y4 )
        hi = max( y1, y2, y3, y4 )

        return Bint( lo, hi )
end

function Base.:*( n1::Bint{lo1,hi1,T1}, n2::Bint{lo2,hi2,T2} ) where {lo1,hi1,T1,lo2,hi2,T2}
        return (Bint{lo1,hi1,T1} * Bint{lo2,hi2,T2})( n1.n * n2.n, Val{false}() )
end

# unary negate
# type level:
function Base.:-( ::Type{Bint{lo1,hi1,T1}} ) where {lo1,hi1,T1}
        return Bint( -hi1, -lo1 )
end
# value level:
function Base.:-( n1::Bint{lo1,hi1,T1} ) where {lo1,hi1,T1}
        return (-Bint(lo1,hi1) )( -n1.n )
end

# ones complement:
# type level:
function Base.:~( ::Type{Bint{lo1,hi1,T1}} ) where {lo1,hi1,T1}
        return Bint( ~hi1, ~lo1 )
end
# function level:
function Base.:~( n1::Bint{lo1,hi1,T1} ) where {lo1,hi1,T1}
        return (~Bint{lo1,hi1,T1})( ~n1.n )
end


# need comparison for clamp( Bints.uBint(4)(12), Bints.uBint(3) )
# probably don't need all these (Julia can combine <, = to get the others?)
for op in ( :(==), :!=, :<, :<=, :>, :>= )
        eval( quote
                function Base.$op( n1::Bint, n2::Bint )
                        return n3 = Base.$op( n1.n, n2.n )
                end
        end )
end  





num_bits_required_unsigned( n ) = begin
        @assert( n >= 0 )
        
        # zero requires zero bits..
        # this special case comes up in the important case of 
        # determining num bits for Bint(-1,0)
        return n == 0 ? 0 : ndigits( n ; base=2 )
end

num_bits_required_signed( n ) = begin
        # extra bit required for sign bit
        n_bits = num_bits_required_unsigned( n < 0 ? ~n : n ) + 1 
        return n_bits
end
num_bits_required_signed( ::Type{Bint{lo,hi,T}} ) where {lo,hi,T} = begin
        nbits_hi = num_bits_required_signed( hi )
        nbits_lo = num_bits_required_signed( lo )
        n_bits = max( nbits_lo, nbits_hi )
        return n_bits
end
num_bits_required_unsigned( ::Type{Bint{lo,hi,T}} ) where {lo,hi,T} = begin
        # really only need to look at hi, and check that lo >= 0
        # but doing it similarily to num_bits_required_signed anyway
        nbits_hi = num_bits_required_unsigned( hi )
        nbits_lo = num_bits_required_unsigned( lo )
        n_bits = max( nbits_lo, nbits_hi )
        return n_bits
end
# type level:
function FixedWidths.num_bits_required( ::Type{Bint{lo,hi,T}} ) where {lo,hi,T}
        n = if lo < 0
                nbits_hi = num_bits_required_signed( hi )
                nbits_lo = num_bits_required_signed( lo )
                max( nbits_lo, nbits_hi )
        else
                num_bits_required_unsigned( hi )
        end

        return n
end
# # value level:
# function FixedWidths.num_bits_required( ::Bint{lo,hi,T} ) where {lo,hi,T}
#         return FixedWidths.num_bits_required( Bint{lo,hi,T} )
# end
# these mostly return types not values:

# Bint type corresponding to nbits unsigned
uBint( nbits::Int ) = Bint{ 0, (1<<nbits)-1, Int64 }  # TODO: Int64...
sBint( nbits::Int ) = Bint{ -( 1<<(nbits-1) ),( 1<<(nbits-1) ) - 1, Int64 } # TODO: Int64...

# this function should be subsumed by the more general function below:
# function uBint( ::Type{Bint{lo,hi} } ) where { lo, hi }
#         @assert lo >= 0
#         return uBint( num_bits_required_unsigned( hi ) )
# end
function uBint( ::Type{I} ) where {I<:FixedWidths.FixedWidth}
        # convert to Int to ensure that we end up calling the sBint() above
        w = FixedWidths.num_bits_required( I ) |> Int
        return uBint(w)
end

# this function is NOT subsumed by the more general function below:
# the difference is when lo > 0, but the request is for a signed type
# so this will require one more bit for sign
function sBint( ::Type{Bint{lo,hi,T} } ) where { lo, hi,T }
        h = max( -lo - 1 , hi )
        return sBint( num_bits_required_signed(h) )
end

function sBint( ::Type{I} ) where {I<:FixedWidths.FixedWidth}
        # convert to Int to ensure that we end up calling the sBint() above
        w = FixedWidths.num_bits_required( I ) |> Int
        return sBint(w)
end

# these are the preferred way of converting from Mint to Bint:
# The Bint is automatically sized correctly
function sBint( n::FixedWidths.FixedWidth )
        return sBint( FixedWidths.num_bits_required( typeof(n) ) |> Int )( Base.signed( n ) )
end
function uBint( n::FixedWidths.FixedWidth )
        return uBint( FixedWidths.num_bits_required( typeof(n) ) |> Int )( Base.unsigned( n ) )
end

import Random
Random.rand(rng::Random.AbstractRNG, ::Random.SamplerType{ Bint{lo,hi,T}}) where {lo,hi,T} = Bint{lo,hi,T}(rand(rng, lo:hi))


# Note: this is acting on the type only
# so show( Bint{-3,3}(2) ) is using this to show the type, and using Julia builtin 
# stuff to show the value 2.

#=

function Base.show( io::IO, ::Type{Bint} )  
        print( io, "Bint" )
end
function Base.show( io::IO, ::Type{Bint{lo,hi}} )  where {lo,hi} # { lo<:Integer, hi<:Integer }
        if lo == -1 && hi == 0
                print(io, "sBint(1)" )
        elseif lo < 0 && ispow2( -lo ) && ispow2( hi+1 ) && -lo == hi+1
                # signed and bounds correspond to signed number:
                nbits = num_bits_required_signed(lo)
                print(io, "sBint(", nbits, ")" )
        elseif lo == 0 && ispow2( hi + 1 )
                # unsigned and power of two
                nbits = num_bits_required_unsigned(hi)
                print(io, "uBint(", nbits, ")" )
        elseif lo == hi
                # constant case - don't need lo or hi here - will be added when the value is printed
                # eg show( FixPt{-2,Bint}(100) )
                print(io, "Bint" )
        else
                # default case:        
                print(io, "Bint{", lo, ",", hi, "}" )
        end
end 

=#

end # module

