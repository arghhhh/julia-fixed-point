
module FixedWidths

abstract type FixedWidth <: Integer end

# this is a namespace for adding functions that are wanted for all valid numeric types that 
# could be embedded in a FixPt.
# Functions that operate on Bint/Mint etc structures are either defined here, or 
# in Base.  (most of them are in Base - things like +,-,*, typemax etc)
#
# These functions are specialized in Bints.jl and Mints.jl
# These functions are used by FixPtImpl.jl and FixPts.jl


# Don't want to use << or >> for specifying the behaviour of HDL integers
# - these operators can be lossy, and I want loss of precision to be explicit

# << is safe when the shift is non-negative.  Ensure this by using left_shift()

# default for standard Julia integer types:

#type_level, b still an int though
left_shift( ::Type{T} , b ) where {T<:Integer} = begin
        @assert b >= 0
        return T
end
# value level:
left_shift( n , b ) = begin
        @assert b >= 0
        return n << b
end



# explicit LSB quantization is OK
# if b < 0, then this will be lossless - this is still valid and not a problem
truncate_lsbs( n, b ) = n >> b
truncate_lsbs( ::Type{T}, b ) where {T} = T

# this is the number of bits required to represent any valid value of n:
num_bits_required( n::Type ) = error( "Type $(n) does not have a defined bit width" )
num_bits_required(  ::Type{ Int128} ) = 128
num_bits_required(  ::Type{ Int64 } ) = 64 
num_bits_required(  ::Type{ Int32 } ) = 32 
num_bits_required(  ::Type{ Int16 } ) = 16 
num_bits_required(  ::Type{ Int8  } ) = 8  
num_bits_required(  ::Type{UInt128} ) = 128
num_bits_required(  ::Type{UInt64 } ) = 64 
num_bits_required(  ::Type{UInt32 } ) = 32 
num_bits_required(  ::Type{UInt16 } ) = 16 
num_bits_required(  ::Type{UInt8  } ) = 8  

end # module

