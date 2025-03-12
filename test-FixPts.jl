


function add_to_Julia_path( p )
        if p ∉ LOAD_PATH
                push!( LOAD_PATH, p )
        end
end
add_to_Julia_path( "." )

using FixPts
using  .FixPts:FixPt

using  Bints
using .Bints:Bint

import Bints 
import Bints.Bint 
import Bints.uBint 
import Bints.sBint

using Test

@testset "fixpt-bint" begin

        @test FixPt{-3}(10) === FixPt{-3,Int64}(10)

        @test FixPt{-3}(10) << 1 === FixPt{-2,Int64}(10)
        @test FixPt{-3}(10) >> 1 === FixPt{-4,Int64}(10)


        # removed this - it is better that Bint behaves like an Int64
        #=
        @test Bint(3) << 1 === FixPt{1}(Bint(3))
        @test Bint(3) >> 1 === FixPt{-1}(Bint(3))
        =#

        # loosened the === to just == to allow UInt64 Int64 to compare equal
        @test FixPt{-3}(Bint(25) ) == FixPt{-3}(Bint{25, 25}(25))

        # loosened the === to just == to allow UInt64 Int64 to compare equal
        @test round( FixPt{-3,Bint}, Float64(pi) ) == FixPt{-3}(Bint{25, 25}(25))

        @test round( FixPt{-3,Bint{-100,100} }, Float64(pi),  RoundDown ) === FixPt{-3}(Bint{-100, 100}(25))

        @test round( FixPt{-3,Bint }, Float64(pi),  RoundDown ) == FixPt{-3}(Bint{25, 25}(25))

        # loosened the === to just == to allow UInt64 Int64 to compare equal
        @test round( FixPt{-3,Int }, Float64(pi),  RoundDown ) === FixPt{-3}(25)

        @test round( FixPt{-3,Bint}, Float64(pi) )             == FixPt{-3}(Bint(25) )
        @test round( FixPt{-3,Bint}, Float64(pi),  RoundDown ) == FixPt{-3}(Bint(25) )
        @test round( FixPt{-3,Bint}, Float64(pi),  RoundUp )   == FixPt{-3}(Bint(26) )

        @test round( FixPt{-3,Bint{-100,100} }, Float64(pi) )             === FixPt{-3}(Bint{-100,100}(25) )
        @test round( FixPt{-3,Bint{-100,100} }, Float64(pi),  RoundDown ) === FixPt{-3}(Bint{-100,100}(25) )
        @test round( FixPt{-3,Bint{-100,100} }, Float64(pi),  RoundUp )   === FixPt{-3}(Bint{-100,100}(26) )


        @test FixPts.sFixPt(2,3) === FixPt{-3, Bint{-16, 15}}
        @test FixPts.uFixPt(2,3) === FixPt{-3, Bint{  0, 31}}

        @test round( FixPts.sFixPt(5,3), Float64(pi) ) === FixPt{-3}( Bint{-128, 127}(25) )

        @test FixPts.sFixPt( FixPt{-3, Bint{-10,200} }  ) === FixPts.sFixPt(6,3)
        @test FixPts.uFixPt( FixPts.uFixPt(2,3)   ) === FixPts.uFixPt(2,3)
        @test FixPts.sFixPt( FixPts.uFixPt(2,3)   ) === FixPts.sFixPt(3,3) # needs extra bit
        @test FixPts.sFixPt( FixPts.sFixPt(2,3)   ) === FixPts.sFixPt(2,3)

        @test FixPt(Bint(10)) >> 3 % FixPts.sFixPt(3,10) === FixPt( Bint{-4096, 4095}(1280) ) << -10

        @test FixPt{-3}(2) + ( FixPt(Bint(1)) >> 2 ) === FixPt{-3}(4)

        # loosened the === to just == to allow UInt64 Int64 to compare equal
        @test FixPts.truncate_lsbs_to(-2,  FixPt{-4}(Bint(15) ) ) == FixPt{-2}(Bint(3) )

        # typelevel:
        @test FixPts.FixPt{ 0,Bint{1,3}} << Bint{-1,3} === FixPt{-1,Bint{1,48}}
        @test FixPts.FixPt{-1,Bint{1,3}} << Bint{-1,3} === FixPt{-2,Bint{1,48}}

        @test FixPts.uFixPt(1,3) + FixPts.uFixPt(1,3) === FixPt{-3,Bint{0,30}}

        # value level:
        @test FixPts.FixPt{ 0,Bint{1,3}}(1) << Bint{-1,3}( 1) === FixPt{-1,Bint{1,48}}(4)
        @test FixPts.FixPt{-1,Bint{1,3}}(1) << Bint{-1,3}( 1) === FixPt{-2,Bint{1,48}}(4)
        @test FixPts.FixPt{ 0,Bint{1,3}}(1) << Bint{-1,3}(-1) === FixPt{-1,Bint{1,48}}(1)
        @test FixPts.FixPt{-1,Bint{1,3}}(1) << Bint{-1,3}(-1) === FixPt{-2,Bint{1,48}}(1)

        @test FixPts.uFixPt(1,3)(2) + FixPts.uFixPt(1,3)(2) === FixPt{-3,Bint{0,30}}(4)

        @test FixPts.split( FixPts.uFixPt(2,2)(9) ) == 
                FixPt[ FixPt{-2,Bint{0,1}}(1) 
                , FixPt{-1,Bint{0,1}}(0) 
                , FixPt{0,Bint{0,1}}(0) 
                , FixPt{1,Bint{0,1}}(1) 
                ]
     
        @test FixPts.split( FixPts.sFixPt(2,2)(-7) ) ==
                FixPt[ FixPt{-2,Bint{0,1}}(1) 
                , FixPt{-1,Bint{0,1}}(0) 
                , FixPt{ 0,Bint{0,1}}(0)  
                , FixPt{ 1,Bint{-1,0}}(-1)
                ]
end
