
# things that depend on both fixpt and bints/mints are here:


module FixPts


import Bints
import Mints 
import FixPtImpl

import .Bints:Bint
import .Mints:Mint
import .FixPtImpl:FixPt, num_bits_required, bitwidth


import FixedWidths


# Barrel shifters - where the RHS is a Bint 
# type level:
function Base.:<<( ::Type{FixPt{e1,T}}, ::Type{Bint{e_lo,e_hi}} ) where { e1,T, e_lo, e_hi }
        e = e1 + e_lo
   #     n = T << Bint{0,e_hi-e_lo}  # typelevel
        n = FixedWidths.left_shift( T , Bint{0,e_hi-e_lo} )  # typelevel
        return FixPt{e, n }
end
# value level:
function Base.:<<( n1::FixPt{e1,T}, e2::Bint{e_lo,e_hi} ) where { e1, T, e_lo, e_hi }
#        n = n1.n << (e2.n - e_lo)
        Tr = FixPt{e1,T} << Bint{e_lo,e_hi}
        n  = FixedWidths.left_shift( n1.n , (e2.n - e_lo) )
#        Tr = FixedWidths.left_shift( FixPt{e1,T} , Bint{e_lo,e_hi} )
        return Tr( n ) 
end

# helpers to get the types from sign,i_bits,q_bits notation
# these return the type, not an instance of the type
function sFixPt(i,q)  
        e = -q
        lo = (~0) << (i+q-1)
        hi = ~lo
        return FixPt{e,Bint{lo,hi}}
end

function uFixPt(i,q)
        e = -q
        lo = 0
        hi = ~( (~0) << (i+q) )
        return FixPt{e,Bint{lo,hi}}
end
# this returns the arguments required to get a minimal sized binary FixPt using sFixPt helper
function sFixPt( ::Type{ FixPt{e,Bint{lo,hi}} } ) where {e,lo,hi}
        q = -e
        nbits = Bints.num_bits_required_signed( Bint{lo,hi} )
        return sFixPt(nbits-q,q)
end
function uFixPt( ::Type{ FixPt{e,Bint{lo,hi}} } ) where {e,lo,hi}
        @assert lo >= 0
        q = -e
        nbits = Bints.num_bits_required_unsigned( Bint{lo,hi} )
        return uFixPt(nbits-q,q)
end
function sFixPt( ::Type{ FixPt{e,Mint{N} } } ) where {e,N}
        return sFixPt(n+e,-e)
end
function uFixPt( ::Type{ FixPt{e,Mint{N} } } ) where {e,N}
        return uFixPt(n+e,-e)
end
function get_i( ::Type{ FixPt{e,Bint{lo,hi}} } ) where {e,lo,hi}
        q = -e
        nbits = lo >= 0 ? Bints.num_bits_required_unsigned( Bint{lo,hi} ) :
                          Bints.num_bits_required_signed(   Bint{lo,hi} )
        return nbits-q
end
function get_q( ::Type{ FixPt{e,Bint{lo,hi}} } ) where {e,lo,hi}
        q = -e
        return q
end

# "modulo" FixPt type, built on Mint (modulo Integer)
function mFixPt(width,e=0)
        return FixPt{e,Mint{width}}
end


# make FixPt constants:

# make a fixed point out of an integer - don't have any information
# about format - so choose the best format - which will be
# an odd number shifted appropriately, or zero
function FixPt( n::T ) where {T <:Integer}
        e = 0
        if n == 0 
                return FixPt{e,Bint(0)}( 0 )
        end
        # truncate lsbs while it reaches a lsb that is set
        while FixedWidths.truncate_lsbs(n,1) << 1 == n
                n = FixedWidths.truncate_lsbs(n,1)
                e = e + 1
        end
        return FixPt{e,Bint{n,n}}( n )
end

# for Bints, already have wordlength information,
# so don't try to reduce the width by looking at the specific value of n
function FixPt( n::Bint{lo,hi} ) where {lo,hi}
        return FixPt{0,Bint{lo,hi}}(n)
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

     #   return FixPt{e,Int64}( r.num )
        return FixPt( r.num ) << e
end


# round and clamp a Float to a FixPt built on a Bint with specified bounds
function Base.round( ::Type{FixPt{e,Bint{lo,hi}}}, x::Float64, mode::RoundingMode=Base.Rounding.RoundNearest ) where {e,lo,hi}
        n1 = round( Int64, ldexp(x,-e), mode )

        # need to clamp for cases like converting +1.0 to sFixPt(1,15) which overlaods the quantizer slightly
        n2 = clamp( n1, Bint{lo,hi} )
        return  FixPt{e,Bint{lo,hi}}( n2 )
 #       # but the above stops some tests from passing - where T is just specified as a Bint without bounds
  #      return  FixPt{e,T}( n1 )
end




#=

# corners of Julia that I don't fully understand - you can have types where 
# the type parmeters are not specified - eg
# FixPt[ uFixPt(2,3)(1), uFixPt(4,1)(2), uFixPt(1,5)(3), sFixPt(1,6)(4) ]
# the result of this is Vector{FixPt{?,?}} (alias for Array{FixPt{?,?}, 1})

# these are all at the type level:

function Base.show( io::IO, ::Type{ FixPt } )
        print(io, "FixPt{?,?}" )
end
function Base.show( io::IO, ::Type{ FixPt{e} } ) where {e}
        print(io, "FixPt{$(e),?}" )
end
function Base.show( io::IO, ::Type{ FixPt{e,Bint} } ) where {e}
        print(io, "FixPt{$(e),Bint{?,?}}" )
end

function Base.show( io::IO, ::Type{ FixPt{e,Bint{lo,hi}} } ) where {e,lo,hi}
        if lo == hi
                # constant value
                nbits = lo < 0 ? Bints.num_bits_required_signed(lo) : Bints.num_bits_required_unsigned(lo)
                q = -e
                i = nbits-q
                print( io, "FixPt{$(e),Bint($(lo))}" )
        elseif lo >= -1 && hi <= 1
                # print single bits as normal Bints and never as uFixPt or sFixPt
                print( io, "FixPt{$(e),Bint{$(lo),$(hi)}}" )
        elseif lo < 0
                # signed
                nbits = round( Int, log2( -lo ) ) + 1
                i = nbits + e
                q = nbits - i

                if sFixPt(i,q) === FixPt{e,Bint{lo,hi}}
                        print( io, "sFixPt($(i),$(q))" )
                else
                        print( io, "FixPt{$(e),Bint{$(lo),$(hi)}}" )
                end
        elseif lo == 0
                nbits = round( Int, log2( hi + 1 ) ) # TODO: possible overflow here
                i = nbits + e
                q = nbits - i
                if uFixPt(i,q) === FixPt{e,Bint{lo,hi}}
                        print( io, "uFixPt($(i),$(q))" )
                else
                        print( io, "FixPt{$(e),Bint{$(lo),$(hi)}}" )
                end
        else
                print( io, "FixPt{$(e),Bint{$(lo),$(hi)}}" )
        end
end

=#



# % operator just takes the bits that are required for the output
# truncates MSBs and LSBs as required
# Julia already has % that can do (100 % Mints.Mint{6})

# Not convinced that this operator is useful
# TODO: maybe get rid of this?
function Base.:%( n::FixPt{n_e}, ::Type{ FixPt{e,T} } ) where {n_e,e,T}

        n1 = Integer( n.n )
        n2 = n1 << (n_e-e)  # could be lossy
        n3 = n2 % T
        n4 = FixPt{e,T}( n3 )

        return n4
end




#  truncation should always be explicit:
#=
function truncate_lsbs_to(e1, n::FixPt{e,Bint{lo,hi} } ) where {e,lo,hi}
        n_bits_truncated = e1 - e
        n    = FixedWidths.truncate_lsbs( n.n.n , n_bits_truncated )
        n_lo = FixedWidths.truncate_lsbs( lo    , n_bits_truncated )
        n_hi = FixedWidths.truncate_lsbs( hi    , n_bits_truncated )
        return FixPt{e1,Bint{n_lo,n_hi}}( n ) 
end
function truncate_lsbs_to(e1, ::Type{ FixPt{e,Bint{lo,hi} } } ) where {e,lo,hi}
        n_bits_truncated = e1 - e
        n_lo = FixedWidths.truncate_lsbs( lo    , n_bits_truncated )
        n_hi = FixedWidths.truncate_lsbs( hi    , n_bits_truncated )
        return FixPt{e1,Bint{n_lo,n_hi}}
end
=#
function truncate_lsbs_to(e1, n::FixPt{e,T } ) where {e,T}
        n_bits_truncated = e1 - e
 
        n1 = FixedWidths.truncate_lsbs( n.n , n_bits_truncated )
        y = FixPt{e1}( n1 )
        return y
end
function truncate_lsbs_to(e1, ::Type{ FixPt{e,T } } ) where {e,T}
        n_bits_truncated = e1 - e
        Ty = FixedWidths.truncate_lsbs( T    , n_bits_truncated )
        return FixPt{e1,Ty}
end

function truncate_lsbs_by(n_bits_truncated, n::FixPt{e,T } ) where {e,T} 
        n1 = FixedWidths.truncate_lsbs( n.n , n_bits_truncated )
        y = FixPt{e1}( n1 )
        return y
end
function truncate_lsbs_by(n_bits_truncated, ::Type{ FixPt{e,T } } ) where {e,T}
        Ty = FixedWidths.truncate_lsbs( T    , n_bits_truncated )
        return FixPt{e1,Ty}
end





# Could use Julia's round( ) with mode set to :Down for truncation
# - but this gets complicated quick, and it isn't ideal when really, for hardware, 
#   you want to say, truncate some bits, and let the bounds be calculated rather 
#   than say, round( FixPt{e,Bint{lo,hi}}, x )
#   (could define  round( FixPt{e,Bint} , x )
# 
# function Base.round( FixPt{e2,Bint}, x::FixPt{e,Bint{lo,hi}, RoundDown } ) where {e2,e,lo,hi}
#         return truncate_lsbs_to( e2, x )
# end

# the built-in clamp to type function assumes the type T is T<:Integer which is not true for FixPt
# restrict the input to have same exponent - simpler and make extension and truncation individually explicit
Base.clamp( n::FixPt{e,Bint{nlo,nhi}}, ::Type{ FixPt{e,Bint{lo,hi}} }) where {e,nlo,nhi,lo,hi} = 
        FixPt{e,Bint{lo,hi}}( clamp( n.n.n, lo, hi ) )


# 
# # split a FixPt number at given exponent e2
# function split( n::FixPt{e, Bint{lo,hi} }, e2 ) where {e,lo,hi}
#         n_lsbs = ( -e + e2 )
#         lsb_mask = ~( (~0) << n_lsbs )
# 
#         msbs = FixPt{e2,Bint{lo>>n_lsbs,hi>>n_lsbs}}( FixedWidths.truncate_lsbs( n.n, n_lsbs ) )
#         lsbs = FixPt{e ,Bint{0,lsb_mask}}( n.n & lsb_mask )
# 
#         @assert n == msbs + lsbs 
#         return msbs, lsbs
# end


function split( n::FixPt{e, T }, e2 ) where {e,T}
        n_lsbs = ( -e + e2 )
        lsb_mask = ~( (~0) << n_lsbs )

        msbs = FixPt{e2}( FixedWidths.truncate_lsbs( n.n, n_lsbs ) )
   #     lsbs = FixPt{e ,Bint{0,lsb_mask}}( n.n.n & lsb_mask )  # TODO: exploiting Bint and Mint both having a field n
        lsbs = FixPt{e ,Bint{0,lsb_mask}}( Integer(n.n) & lsb_mask )

   #     @show msbs lsbs msbs + lsbs n
   #     dump(n)
   #     dump( msbs + lsbs )
        @assert n == msbs + lsbs 
        return msbs, lsbs
end



# split a number into single bits
# - the MSB will have negative weight if lo < 0
# function split( n::FixPt{e, Bint{lo,hi} } ) where {e,lo,hi} ======================
function split( n::FixPt{e,T} ) where {e,T}
        n1 = n
        r = FixPt[]
        for i in e+1:e + FixedWidths.num_bits_required( typeof(n.n) ) - 1
                n1, b1 = split( n1, i )
                push!( r, b1 ) 
        end
        # push on the last part - this may be signed, or a FixPt{e,Mint{1}}
        if n1.n isa Bint || n1.n isa Mint
                push!( r, n1 )
        elseif n1.n isa Unsigned
                push!( r, FixPt{e + FixedWidths.num_bits_required( typeof(n.n) ) - 1}( Bint{0,1}( n1.n ) ) )
        elseif n1.n isa Signed
                push!( r, FixPt{e + FixedWidths.num_bits_required( typeof(n.n) ) - 1}( Bint{-1,0}( n1.n ) ) )
        else
                error( "Left with $(n1)" )
        end
        return r
end

# coverting to/from BitVector
# using Random: bitrand
# bv = bitran(10)
# n = evalpoly( 2, bv )
# digits( n, base=2, pad=8 ) # pad is minimum width


end # module
