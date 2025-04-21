


module BigIntBitsType

# adapted from https://github.com/arghhhh/bint-juliacon2016/blob/master/bint-type-const.jl


# this doesn't actually put anything into the type form
# It transforms any number into a bitstype that can hold that number


#function make_number_from_tuple( n::Tuple ; base = 1000 )
#        return foldl( (a,b)-> a*base+b, big(0), n )
#end
function make_number_from_tuple( n::Tuple ; base = 1000 )
        # BigInts to ensure known return type
        fn(a::BigInt,b) = BigInt( a*base+b )
    #    return foldl( fn, big(0), n )
        return foldl( fn, n; init = big(0) )
end



function make_tuple_from_number( n; last_digits = tuple(), base =1000 )
        if -base < n < base
                return ( oftype(base,n),last_digits...)
        end
        next_n, next_digit = fldmod(n,base)
        return make_tuple_from_number( next_n; last_digits = (oftype( base, next_digit ),last_digits...), base = base )
end


# for testing:
function tuple_number_round_trip( n ; base =1000 )
        t = make_tuple_from_number( n; base=base )
        n2 = make_number_from_tuple( t; base=base )
        @assert( n == n2 )
        return n2
end


function to_type_constant( n::Integer )
        if     Int == Int32 && typemin(Int32)  <= n <= typemax(Int32)
                # only for machines where Int is Int32
                return Int32(n)
        elseif typemin(Int64)  <= n <= typemax(Int64)
                return Int64(n)
        elseif typemin(Int128) <= n <= typemax(Int128)
                return Int128(n)
        else
                return make_tuple_from_number(n )
        end
end

function from_type_constant( n::Integer )
        return BigInt(n)
end

function from_type_constant( n::Tuple )
        return make_number_from_tuple( n )
end

end # module

