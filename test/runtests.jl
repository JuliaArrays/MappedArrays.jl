using MappedArrays
using Base.Test

a = [1,4,9,16]
b = mappedarray(sqrt, a)
@test eltype(b) == Float64
@test @inferred(getindex(b, 1)) == 1
@test b[2] == 2
@test b[3] == 3
@test b[4] == 4
@test_throws ErrorException b[3] = 0
c = mappedarray((sqrt, x->x*x), a)
@test @inferred(getindex(c, 1)) == 1
@test c[2] == 2
@test c[3] == 3
@test c[4] == 4
c[3] = 2
@test a[3] == 4
@test_throws InexactError c[3] = 2.2  # because the backing array is Array{Int}
sb = similar(b)
@test isa(sb, Array{Float64})
@test size(sb) == size(b)
