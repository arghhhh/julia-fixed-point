
function add_to_Julia_path( p )
        if p ∉ LOAD_PATH
                push!( LOAD_PATH, p )
        end
end
add_to_Julia_path( "." )

import Bints 
import Bints.Bint 
import Bints.uBint 
import Bints.sBint

import FixedWidths

using Test

@testset "Bints" begin

        @test Bint{-10,10}(5).n == 5
        @test_throws OverflowError Bint{-10, 10}( 20 )
        @test Bint{-100,100}( Bint{-10,10}(5) ) == Bint{-100,100}(5)

        @test uBint(4) == Bint{0,15}
        @test uBint( Bint{2,10} ) == Bint{0,15}
        @test sBint(4) == Bint{-8,7}
        @test sBint( Bint{2,5} ) == Bint{-8,7}

        @test zero( Bint{-5,5} ) == Bint{-5,5}(0)
        @test one( Bint{-5,5} ) == Bint{-5,5}(1)
        @test_throws OverflowError zero( Bint{2,5} )

        @test clamp( 10,  Bint{-5,5} ) == Bint{-5,5}(5)

        # this conversion was removed
        # @test Int( Bint{-10,10}(5) ) == 5

        @test Integer( Bint{-10,10}(5) ) == 5

        @test Bint{-10,10}( 10, Val{false}() ) == Bint{-10,10}( 10 )
        @test Float64( Bint{-10,10}( 6 ) ) == 6.0

        @test Bint{-10,10}(1) + Bint{-10,10}(1) == Bint{-20,20}(2)
        @test Bint{-10,10}(2) - Bint{-10,10}(1) == Bint{-20,20}(1)
        @test Bint{-10,10}(2) * Bint{-10,10}(2) == Bint{-100,100}(4)

        # type level operations:
        @test Bint{-10,10} + Bint{-10,10} == Bint{-20,20}
        @test Bint{-10,10} - Bint{-10,10} == Bint{-20,20}
        @test Bint{-10,10} * Bint{-10,10} == Bint{-100,100}
        @test -Bint{-1,10} == Bint{-10,1}
        @test ~Bint{-1,10} == Bint{-11,0}

        @test FixedWidths.left_shift( Bint{-2, 3} , Bint{1,3} ) == Bint{-16,24}   # straddle zero
        @test FixedWidths.left_shift( Bint{-3,-1} , Bint{1,3} ) == Bint{-24,-2}   # all negative
        @test FixedWidths.left_shift( Bint{ 2, 3} , Bint{1,3} ) == Bint{  4,24}   # all positive

        # value level:
        @test FixedWidths.left_shift( Bint{-2, 3}(-1) , Bint{1,3}(1) ) == Bint{-16,24}(-2)  # straddle zero
        @test FixedWidths.left_shift( Bint{-3,-1}(-1) , Bint{1,3}(1) ) == Bint{-24,-2}(-2)  # all negative
        @test FixedWidths.left_shift( Bint{ 2, 3}( 2) , Bint{1,3}(1) ) == Bint{  4,24}( 4)  # all positive

        # some interesting corner cases:
        # see: https://www.dsprelated.com/showarticle/1482.php (particularly the comments)
        @test uBint(1) * uBint(1) === uBint(1)    # requires 1 bit
        @test sBint(1) * sBint(1) === uBint(1)    # requires 1 bit, and no signbit
        # now increase one of the input widths by one bit:
        @test sBint(2) * sBint(1) === Bint{-1,2}  # now requires 3 bits
        @test uBint(1) * sBint(4) === sBint(4)    # requires 4 bits
        # now increase one of the input widths by one bit:
        @test uBint(2) * sBint(4) === Bint{-24,21}  # 0..3 * -8..7 and now requires 6 bits

        # these test the customized show (at type level) implementation for special cases of Bint
        # @test sprint( show, uBint(4)    ) == "uBint(4)"
        # @test sprint( show, sBint(4)    ) == "sBint(4)"
        # @test sprint( show, uBint(4)(2) ) == "uBint(4)(2)"
        # @test sprint( show, sBint(4)(3) ) == "sBint(4)(3)"
        # @test sprint( show, Bint{-10,10}(2) ) == "Bint{-10,10}(2)"
        # @test sprint( show, Bint{-3,3}(2) ) == "Bint{-3,3}(2)"
end






nothing

