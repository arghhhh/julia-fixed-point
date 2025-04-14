# julia-fixed-point
Fixed point numbers in Julia.

## Why? What is this for?

I have seen many implementations for fixed point numbers, and I have written quite a few.
Many implementations make assumptions that are not appropriate in all use cases especially for hardware description.


## Major differences

Attempts to be more mathematically sound.  I am not a mathematician, and none is this is formally defined - though maybe one day...
All "lossy" operations are explicit.  Normal arithmetic operations +,-,* are exact.  Bitwise shifts are exact.  Logical operations are not defined - though you can extract the bit pattern if you really must, though doing this is a questionable practice.

Rounding, overflow, clamping are properties of operations on fixed point numbers and not of the numbers themselves.

The library attempts to be structured.

There are two main integer types defined - Bounded Integers ("Bints" defined in Bints.jl) and Modulo Integers ("Mints" defined in Mints.jl).  These files 
add arithmetic operations to the Julia Base module.  A few extra properties are defined in the FixedWidths.jl module.  The definitions in FixedWidths.jl 
supply default implementations that are suitable for the Julia built in integer types (Int16, Int64, UInt16, UInt64 etc).

The implementation of FixPts is made in FixPtImpl.jl by making general use of integer operations defined in the Julia Base module (and potentially extended 
for particular implementations such as Bints and Mints).  FixPtImpl.jl does not depend on Bints.jl or Mints.jl.

The top level of the library is FixPts.jl.  This includes both Bints.jl and Mints.jl as well as the generic fixed point implementation FixPtImpl.jl 
and also adds functions that require specific knowledge of Bints.jl or Mints.jl



SystemC - associates rounding with numeric types rather than operations on numbers.


# Detailed Description

## Anatomy of a Fixed Point Number

Fixed point number is an finite length bitvector, with associated information on where the binary point is.
Note that the binary point can appear anywhere - even beyond the ends of the bitvector.

Many fixed point libraries have two types - one for signed and one for unsigned numbers.  Unsigned numbers are assumed to be stored in binary.
Signed numbers are assumed to be stored in two's complement form.

In general, the finite bitvector can be be extended at each end.
At the least significant bit end, the value of each bit location smaller than the LSB can be assumed to be zero.
At the most significant bit end, the values of each bit location larger than the MSB fall into a different categories:

For unsigned numbers, extended MSBs are zero.
For numbers in two's complement form, extended MSBs have the same value as the MSB.  The weight of the most significant bit for 
a twos complement number is the negative of that for the corresponding bit of the corresponding length unsigned number.  This is the only 
difference between unsigned and signed bianry formats.
For modulo(2^N) numbers, the bits beyond the MSB are unknown.  Any attempt to use them will introduce unknowns into the result.  For example, 
any operation which attempts to make a number samller, eg a right shift, or a multiplication by a fraction (which is just 
right shifts combined with conditionals and addition).

### Exponent and Underlying Integer



