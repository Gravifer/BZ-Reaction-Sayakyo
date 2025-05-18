using DrWatson, Test
@quickactivate "BZ_Bridge" # using BZ_Bridge

# Here you include files using `srcdir`
# include(srcdir("file.jl"))

# Run test suite
println("Starting tests")
ti = time()

@testset "BZ_Bridge.jl" begin
    @test 1 == 1 # Write your tests here.
end

ti = time() - ti
println("\nTest took total time of:")
println(round(ti/60, digits = 3), " minutes")
