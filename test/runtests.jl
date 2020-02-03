using MappedArrays
using Test

@test isempty(detect_ambiguities(MappedArrays, Base, Core))

using FixedPointNumbers, OffsetArrays, ColorTypes

@testset "ReadonlyMappedArray" begin
    a = [1,4,9,16]
    s = view(a', 1:1, [1,2,4])

    b = @inferred(mappedarray(sqrt, a))
    @test parent(b) === a
    @test eltype(b) == Float64
    @test @inferred(getindex(b, 1)) == 1
    @test b[2] == 2
    @test b[3] == 3
    @test b[4] == 4
    @test_throws ErrorException b[3] = 0
    @test isa(eachindex(b), AbstractUnitRange)
    b = mappedarray(sqrt, a')
    @test isa(eachindex(b), AbstractUnitRange)
    b = mappedarray(sqrt, s)
    @test isa(eachindex(b), CartesianIndices)
    c = Base.unaliascopy(b)
    @test c == b
    @test c !== b
end

@testset "MappedArray" begin
    intsym = Int == Int64 ? :Int64 : :Int32
    a = [1,4,9,16]
    s = view(a', 1:1, [1,2,4])
    c = @inferred(mappedarray(sqrt, x->x*x, a))
    @test parent(c) === a
    @test @inferred(getindex(c, 1)) == 1
    @test c[2] == 2
    @test c[3] == 3
    @test c[4] == 4
    c[3] = 2
    @test a[3] == 4
    @test_throws InexactError(intsym, Int, 2.2^2) c[3] = 2.2  # because the backing array is Array{Int}
    @test isa(eachindex(c), AbstractUnitRange)
    b = @inferred(mappedarray(sqrt, a'))
    @test isa(eachindex(b), AbstractUnitRange)
    c = @inferred(mappedarray(sqrt, x->x*x, s))
    @test isa(eachindex(c), CartesianIndices)

    d = Base.unaliascopy(c)
    @test c == d
    @test c !== d
    
    sb = similar(b)
    @test isa(sb, Array{Float64})
    @test size(sb) == size(b)

    a = [0x01 0x03; 0x02 0x04]
    b = @inferred(mappedarray(y->N0f8(y,0), x->x.i, a))
    for i = 1:4
        @test b[i] == N0f8(i/255)
    end
    b[2,1] = 10/255
    @test a[2,1] == 0x0a
end

@testset "of_eltype" begin
    a = [0.1 0.3; 0.2 0.4]
    b = @inferred(of_eltype(N0f8, a))
    @test b[1,1] === N0f8(0.1)
    b = @inferred(of_eltype(zero(N0f8), a))
    @test b[1,1] === N0f8(0.1)
    b[2,1] = N0f8(0.5)
    @test a[2,1] == N0f8(0.5)
    @test !(b === a)
    b = @inferred(of_eltype(Float64, a))
    @test b === a
    b = @inferred(of_eltype(0.0, a))
    @test b === a
end

@testset "OffsetArrays" begin
    a = OffsetArray(randn(5), -2:2)
    aabs = mappedarray(abs, a)
    @test axes(aabs) == (-2:2,)
    for i = -2:2
        @test aabs[i] == abs(a[i])
    end
end

@testset "No zero(::T)" begin
    astr = @inferred(mappedarray(length, ["abc", "onetwothree"]))
    @test eltype(astr) == Int
    @test astr == [3, 11]
    a = @inferred(mappedarray(x->x+0.5, Int[]))
    @test eltype(a) == Float64

    # typestable string
    astr = @inferred(mappedarray(uppercase, ["abc", "def"]))
    @test eltype(astr) == String
    @test astr == ["ABC","DEF"]
end

@testset "ReadOnlyMultiMappedArray" begin
    a = reshape(1:6, 2, 3)
#    @test @inferred(axes(a)) == (Base.OneTo(2), Base.OneTo(3))
    b = fill(10.0f0, 2, 3)
    M = @inferred(mappedarray(+, a, b))
    @test @inferred(eltype(M)) == Float32
    @test @inferred(IndexStyle(M)) == IndexLinear()
    @test @inferred(IndexStyle(typeof(M))) == IndexLinear()
    @test @inferred(size(M)) === size(a)
    @test @inferred(axes(M)) === axes(a)
    @test M == a + b
    @test @inferred(M[1]) === 11.0f0
    @test @inferred(M[CartesianIndex(1, 1)]) === 11.0f0
    
    d = Base.unaliascopy(b)
    @test d == b
    @test d !== b

    c = view(reshape(1:9, 3, 3), 1:2, :)
    M = @inferred(mappedarray(+, c, b))
    @test @inferred(eltype(M)) == Float32
    @test @inferred(IndexStyle(M)) == IndexCartesian()
    @test @inferred(IndexStyle(typeof(M))) == IndexCartesian()
    @test @inferred(axes(M)) === axes(c)
    @test M == c + b
    @test @inferred(M[1]) === 11.0f0
    @test @inferred(M[CartesianIndex(1, 1)]) === 11.0f0
end

@testset "MultiMappedArray" begin
    intsym = Int == Int64 ? :Int64 : :Int32
    a = [0.1 0.2; 0.3 0.4]
    b = N0f8[0.6 0.5; 0.4 0.3]
    c = [0 1; 0 1]
    f = RGB{N0f8}
    finv = c->(red(c), green(c), blue(c))
    M = @inferred(mappedarray(f, finv, a, b, c))
    @test @inferred(eltype(M)) == RGB{N0f8}
    @test @inferred(IndexStyle(M)) == IndexLinear()
    @test @inferred(IndexStyle(typeof(M))) == IndexLinear()
    @test @inferred(size(M)) === size(a)
    @test @inferred(axes(M)) === axes(a)
    @test M[1,1] === RGB{N0f8}(0.1, 0.6, 0)
    @test M[2,1] === RGB{N0f8}(0.3, 0.4, 0)
    @test M[1,2] === RGB{N0f8}(0.2, 0.5, 1)
    @test M[2,2] === RGB{N0f8}(0.4, 0.3, 1)
    M[1,2] = RGB(0.25, 0.35, 0)
    @test M[1,2] === RGB{N0f8}(0.25, 0.35, 0)
    @test a[1,2] == N0f8(0.25)
    @test b[1,2] == N0f8(0.35)
    @test c[1,2] == 0
    @test_throws InexactError(intsym, Int, N0f8(0.45)) M[1,2] = RGB(0.25, 0.35, 0.45)
    R = reinterpret(N0f8, M)
    @test R == N0f8[0.1 0.25; 0.6 0.35; 0 0; 0.3 0.4; 0.4 0.3; 0 1]
    R[2,1] = 0.8
    @test b[1,1] === N0f8(0.8)

    a = view(reshape(0.1:0.1:0.6, 3, 2), 1:2, 1:2)
    M = @inferred(mappedarray(f, finv, a, b, c))
    @test @inferred(eltype(M)) == RGB{N0f8}
    @test @inferred(IndexStyle(M)) == IndexCartesian()
    @test @inferred(IndexStyle(typeof(M))) == IndexCartesian()
    @test @inferred(axes(M)) === axes(a)
    @test M[1,1] === RGB{N0f8}(0.1, 0.8, 0)
    @test_throws ErrorException("indexed assignment fails for a reshaped range; consider calling collect") M[1,2] = RGB(0.25, 0.35, 0)

    d = Base.unaliascopy(M)
    @test d == M
    @test d !== M
    
    a = reshape(0.1:0.1:0.6, 3, 2)
    @test_throws DimensionMismatch mappedarray(f, finv, a, b, c)
end

@testset "Display" begin
    a = [1,2,3,4]
    b = mappedarray(sqrt, a)
    @test summary(b) == "4-element mappedarray(sqrt, ::Array{Int64,1}) with eltype Float64"
    c = mappedarray(sqrt, x->x*x, a)
    @test summary(c) == "4-element mappedarray(sqrt, x->x * x, ::Array{Int64,1}) with eltype Float64"
    # issue #26
    M = @inferred mappedarray((x1,x2)->x1+x2, a, a)
    io = IOBuffer()
    show(io, MIME("text/plain"), M)
    str = String(take!(io))
    @test occursin("x1 + x2", str)
end
