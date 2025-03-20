
# this defines what a FixPt number is - without needing to know much about the
# underlying integer type - what is required by the underlying type are 
# fairly standard arithemtic operations defined in Julia Base module, and a few 
# operations defined in the FixedWidths module.
# 

module FixPtImpl

import FixedWidths

struct FixPt{e,T} <: Real
        n::T
end

# # extract exponent from FixPt number or Type:
get_exponent( n::FixPt{e,T} ) where {e,T} = e
get_exponent( ::Type{FixPt{e,T}} ) where {e,T} = e

# show FixPt at the value level:
function Base.show( io::IO, f::FixPt{e} ) where {e}
        print(io, "FixPt{" ,e , "}(", f.n, ") #= ", ldexp( Float64( convert( Float64, f.n) ) , e ), " =#" )
end 

# at the type level:
# this allows FixPt{-10}( Bint{-10,10} ) to return the type FixPt{-10, Bint{-10,10}}
function FixPt{e}( ::Type{T} ) where {e,T}
        return FixPt{e,T}
end

function FixPt{e}( n::T ) where { e, T <:Integer}
        return FixPt{e,T}( n )
end

function FixPt( n::T, e=0 ) where {T <:Integer}
        return FixPt{e,T}( n )
end
function FixPt( n::Float64 )

        # all floating point numbers (other than NaN, Inf) are 
        # exact rationals with a power of two denominator

        n1,e1 = frexp(n)
        r = Rational( n1 )
        @assert ispow2( r.den )

        e = -ndigits( r.den, base = 2 )+1 + e1

        n_reconstructed = ldexp( Float64(r.num), e )

        # check for exactness:
        @assert n == n_reconstructed

        return FixPt{e,Int64}( r.num )
end

# round and clamp a Float to a FixPt
function Base.round( ::Type{FixPt{e,T}}, x::Float64, mode::RoundingMode=Base.Rounding.RoundNearest ) where {e,T}
        n1 = round( Int64, ldexp(x,-e), mode )

        # need to clamp for cases like converting +1.0 to sFixPt(1,15) which overlaods the quantizer slightly
        n2 = clamp( n1, T )
        return  FixPt{e,T}( n2 )
end


# make a FixPt from another FixPt - must be lossless
function FixPt{e,T_out}( n::FixPt{e_in,T_in} ) where {e, e_in, T_out, T_in}
        @assert e <= e_in
        r1 = FixedWidths.left_shift( n.n, e_in - e )
        r2 = FixPt{e,T_out}( r1 )
        return r2
end


# renaming num_bits_required to be bitwidth.  TODO: remove this once migration to new name is complete
function num_bits_required( ::Type{ FixPt{e,T} } ) where {e,T }
        return FixedWidths.num_bits_required( T )
end
# type level:
function bitwidth( ::Type{ FixPt{e,T} } ) where {e,T }
        return FixedWidths.num_bits_required( T )
end
# value level:
function bitwidth( n::FixPt{e,T} ) where {e,T }
        return FixedWidths.num_bits_required( T )
end

for op in ( :+, :- )
        eval( quote
                # typelevel:
                function Base.$op( ::Type{FixPt{e1,T1}}, ::Type{FixPt{e2,T2}} ) where { e1,T1,e2,T2 }
                        e = min( e1, e2 )
                        n1a = FixedWidths.left_shift( T1 , e1-e )
                        n2a = FixedWidths.left_shift( T2 , e2-e )
                        n3 = Base.$op( n1a, n2a )
                        return FixPt{e, n3 }
                end 
                # value level:
                function Base.$op( n1::FixPt{e1,t1}, n2::FixPt{e2,t2} ) where { e1,t1,e2,t2 }
                        e = min( e1, e2 )
                        n1a = FixedWidths.left_shift( n1.n , e1-e )
                        n2a = FixedWidths.left_shift( n2.n , e2-e )
                        n3 = Base.$op( n1a, n2a )
                        return FixPt{e}( n3 )
                end   
        end )
end  

# these are similar to above, except that the return value is not converted to a FixPt
for op in ( :(==), :!=, :<, :<=, :>, :>= )
        eval( quote
                function Base.$op( n1::FixPt{e1}, n2::FixPt{e2} ) where { e1,e2 }
                        e = min( e1, e2 )
                        n1a = FixedWidths.left_shift( n1.n , e1-e)
                        n2a = FixedWidths.left_shift( n2.n , e2-e)
                        n3 = Base.$op( n1a, n2a )
                        return  n3   #  this is different from above
                end
        end )
end  


# unary negate and bitwise invert:
# apply the function to the integer part and retain the exponent:
# type level:
function Base.:-( ::Type{FixPt{e1,T}} ) where { e1, T }
        return FixPt{e1,-T}
end
function Base.:~( ::Type{FixPt{e1,T}} ) where { e1, T }
        return FixPt{e1,~T}
end
# value level:
function Base.:-( n1::FixPt{e1} ) where { e1 }
        return FixPt{e1}( -n1.n )
end
function Base.:~( n1::FixPt{e1} ) where { e1 }
        return FixPt{e1}( ~n1.n )
end


function Base.:*( n1::FixPt{e1}, n2::FixPt{e2} ) where { e1,e2 }
        e = e1 + e2
        n2 = n1.n * n2.n
        return FixPt{e}( n2 )
end
function Base.:*( n1::I, n2::FixPt{e2} ) where { I<:Integer,e2 }
        n2 = n1 * n2.n
        return FixPt{e2}( n2 )
end
function Base.:*( n1::FixPt{e1}, n2::I ) where { e1,I<:Integer }
        n2 = n1.n * n2
        return FixPt{e1}( n2 )
end

Base.Float64( n::FixPt{e1} ) where {e1} = ldexp( Float64(n.n), e1 )


# # this converts (quantizes) from a Float to a FixPt with int type
# function Base.round( ::Type{FixPt{e}}, x::Float64, mode::RoundingMode=Base.Rounding.RoundNearest ) where {e}
#         n1 = round( Int64, ldexp(x,-e), mode )
#         return  FixPt{e}(n1)
# end

Base.zero( ::Type{FixPt{e,T}} ) where {e,T} = FixPt{e}(zero(T))


# Operators << and >> acting on LHS FixPts are always lossless
# - they act on the exponent and leave the underlying bit pattern unchanged

# the RHS of << and >> is expected to be a constant - otherwise the result isn't really FIXED point...
# To implement a barrel shifter, the rhs arg should be a Bint - implemented in FixPts.jl
# independent on the shift amount (within bounds).
# To implement a fixed shift, ideally would use a Bint{N,N} constant - but I'm allowing a plain Int here.
# type level:
function Base.:<<( ::Type{FixPt{e1,T}}, n2::Int64 ) where { e1,T }
        e = e1 + n2
        return FixPt{e,T}
end
# value level:
function Base.:<<( n1::FixPt{e1,T}, n2::Int64 ) where { e1, T }
        return ( FixPt{e1,T} << n2 )( n1.n )
end

import Base.:>>
function Base.:>>( n1::FixPt{e1}, n2::Int64 ) where { e1 }
        e = e1 - n2
        return FixPt{e}( n1.n )
end

# these allow the construction of FixPt from an underlying 
# integer type (LHS) and an exponent (RHS) 
function Base.:<<( n1::N1, n2::Int64 ) where { N1 <: FixedWidths.FixedWidth }
        return FixPt{n2}( n1 )
end
function Base.:>>( n1::N1, n2::Int64 ) where { N1 <: FixedWidths.FixedWidth }
        return FixPt{-n2}( n1 )
end


# not all T will support typemin(T) and typemax(T)
# eg Mint where it is not clear whether typemin/typemax should be
# implemented
function Base.typemin( ::Type{FixPt{e,T}} ) where {e,T}
        return FixPt{e,T}( typemin( T ) )
end
function Base.typemax( ::Type{FixPt{e,T}} ) where {e,T}
        return FixPt{e,T}( typemax( T ) )
end

Base.promote_rule( ::Type{ FixPt{e1,T1 } }, ::Type{ FixPt{e2,T2 } } ) where {e1,T1,e2,T2} = begin
        e = min( e1, e2 )
        shift = e1-e
        @assert shift >= 0
        T1shift = FixedWidths.left_shift( T1, shift )
        T2shift = FixedWidths.left_shift( T2, shift )
        
        T12shift_promote = promote_type( T1shift, T2shift )
 
        return FixPt{e,T12shift_promote}
end

# this is assuming that any given integer will be convertable with range given by the FixPt{e1,T1 }
Base.promote_rule( ::Type{ FixPt{e1,T1 } }, ::Type{ T2 } ) where {e1,T1,T2<:Integer} = Base.promote_rule( FixPt{e1,T1 }, FixPt{0,T2 } )

import Random
Random.rand(rng::Random.AbstractRNG, ::Random.SamplerType{ FixPt{e1,T1 }}) where {e1,T1} = FixPt{e1,T1 }(rand(rng, T1))


end

