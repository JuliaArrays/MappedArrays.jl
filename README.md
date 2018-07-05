# MappedArrays

[![Build Status](https://travis-ci.org/JuliaArrays/MappedArrays.jl.svg?branch=master)](https://travis-ci.org/JuliaArrays/MappedArrays.jl)

[![codecov.io](http://codecov.io/github/JuliaArrays/MappedArrays.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaArrays/MappedArrays.jl?branch=master)

This package implements "lazy" in-place elementwise transformations of
arrays for the Julia programming language. Explicitly, it provides a
"view" `M` of an array `A` so that `M[i] = f(A[i])` for a specified
(but arbitrary) function `f`, without ever having to compute `M`
explicitly (in the sense of allocating storage for `M`).  The name of
the package comes from the fact that `M == map(f, A)`.

## Usage

### Single source arrays

```jl
julia> using MappedArrays

julia> a = [1,4,9,16]
4-element Array{Int64,1}:
  1
  4
  9
 16

julia> b = mappedarray(sqrt, a)
4-element MappedArrays.ReadonlyMappedArray{Float64,1,Array{Int64,1},Base.#sqrt}:
 1.0
 2.0
 3.0
 4.0

julia> b[3]
3.0
```

Note that you can't set values in the array:

```jl
julia> b[3] = 2
ERROR: indexed assignment not defined for MappedArrays.ReadonlyMappedArray{Float64,1,Array{Int64,1},Base.#sqrt}
 in setindex!(::MappedArrays.ReadonlyMappedArray{Float64,1,Array{Int64,1},Base.#sqrt}, ::Int64, ::Int64) at ./abstractarray.jl:781
 in eval(::Module, ::Any) at ./boot.jl:231
 in macro expansion at ./REPL.jl:92 [inlined]
 in (::Base.REPL.##1#2{Base.REPL.REPLBackend})() at ./event.jl:46
```

**unless** you also supply the inverse function, using `mappedarray(f, finv, A)`:

```
julia> c = mappedarray(sqrt, x->x*x, a)
4-element MappedArrays.MappedArray{Float64,1,Array{Int64,1},Base.#sqrt,##1#2}:
 1.0
 2.0
 3.0
 4.0

julia> c[3]
3.0

julia> c[3] = 2
2

julia> a
4-element Array{Int64,1}:
  1
  4
  4
 16
```

Naturally, the "backing" array `a` has to be able to represent any value that you set:

```jl
julia> c[3] = 2.2
ERROR: InexactError()
 in setindex!(::MappedArrays.MappedArray{Float64,1,Array{Int64,1},Base.#sqrt,##1#2}, ::Float64, ::Int64) at /home/tim/.julia/v0.5/MappedArrays/src/MappedArrays.jl:27
 in eval(::Module, ::Any) at ./boot.jl:231
 in macro expansion at ./REPL.jl:92 [inlined]
 in (::Base.REPL.##1#2{Base.REPL.REPLBackend})() at ./event.jl:46
```

because `2.2^2 = 4.84` is not representable as an `Int`. In contrast,

```jl
julia> a = [1.0, 4.0, 9.0, 16.0]
4-element Array{Float64,1}:
  1.0
  4.0
  9.0
 16.0

julia> c = mappedarray(sqrt, x->x*x, a)
4-element MappedArrays.MappedArray{Float64,1,Array{Float64,1},Base.#sqrt,##3#4}:
 1.0
 2.0
 3.0
 4.0

julia> c[3] = 2.2
2.2

julia> a
4-element Array{Float64,1}:
  1.0
  4.0
  4.84
 16.0
```

works without trouble.

So far our examples have all been one-dimensional, but this package
also supports arbitrary-dimensional arrays:

```jl
julia> a = randn(3,5,2)
3×5×2 Array{Float64,3}:
[:, :, 1] =
  1.47716    0.323915   0.448389  -0.56426   2.67922
 -0.255123  -0.752548  -0.41303    0.306604  1.5196
  0.154179   0.425001  -1.95575   -0.982299  0.145111

[:, :, 2] =
 -0.799232  -0.301813  -0.457817  -0.115742  -1.22948
 -0.486558  -1.27959   -1.59661    1.05867    2.06828
 -0.315976  -0.188828  -0.567672   0.405086   1.06983

julia> b = mappedarray(abs, a)
3×5×2 MappedArrays.ReadonlyMappedArray{Float64,3,Array{Float64,3},Base.#abs}:
[:, :, 1] =
 1.47716   0.323915  0.448389  0.56426   2.67922
 0.255123  0.752548  0.41303   0.306604  1.5196
 0.154179  0.425001  1.95575   0.982299  0.145111

[:, :, 2] =
 0.799232  0.301813  0.457817  0.115742  1.22948
 0.486558  1.27959   1.59661   1.05867   2.06828
 0.315976  0.188828  0.567672  0.405086  1.06983
```

### Multiple source arrays

Just as `map(f, a, b)` can take multiple containers `a` and `b`, `mappedarray` can too:
```julia
julia> a = [0.1 0.2; 0.3 0.4]
2×2 Array{Float64,2}:
 0.1  0.2
 0.3  0.4

julia> b = [1 2; 3 4]
2×2 Array{Int64,2}:
 1  2
 3  4

julia> c = mappedarray(+, a, b)
2×2 MappedArrays.ReadonlyMultiMappedArray{Float64,2,Tuple{Array{Float64,2},Array{Int64,2}},typeof(+)}:
 1.1  2.2
 3.3  4.4
```

In some cases you can also supply an inverse function, which should return a tuple (one value for each input array):
```julia
julia> using ColorTypes

julia> redchan = [0.1 0.2; 0.3 0.4];

julia> greenchan = [0.8 0.75; 0.7 0.65];

julia> bluechan = [0 1; 0 1];

julia> m = mappedarray(RGB{Float64}, c->(red(c), green(c), blue(c)), redchan, greenchan, bluechan)
2×2 MappedArrays.MultiMappedArray{RGB{Float64},2,Tuple{Array{Float64,2},Array{Float64,2},Array{Int64,2}},DataType,getfield(Main, Symbol("##5#6"))}:
 RGB{Float64}(0.1,0.8,0.0)  RGB{Float64}(0.2,0.75,1.0)
 RGB{Float64}(0.3,0.7,0.0)  RGB{Float64}(0.4,0.65,1.0)

 julia> m[1,2] = RGB(0,0,0)
RGB{N0f8}(0.0,0.0,0.0)

julia> redchan
2×2 Array{Float64,2}:
 0.1  0.0
 0.3  0.4
```

### of_eltype

This package defines a convenience method, `of_eltype`, which
"lazily-converts" arrays to a specific `eltype`.  (It works simply by
defining `convert` functions for both `f` and `finv`.)

Using `of_eltype` you can "convert" a series of arrays to a chosen element type:

```julia
julia> arrays = (rand(2,2), rand(Int,2,2), [0x01 0x03; 0x02 0x04])
(
[0.541018 0.223392; 0.341264 0.022014],

[2437062103055434647 4726011606246170825; -4226911569217925847 -8715663020460318733],

UInt8[0x01 0x03; 0x02 0x04])

julia> arraysT = map(A->of_eltype(Float64, A), arrays)
(
[0.541018 0.223392; 0.341264 0.022014],

[2.43706e18 4.72601e18; -4.22691e18 -8.71566e18],

[1.0 3.0; 2.0 4.0])
```

This construct is inferrable (type-stable), so it can be a useful
means to "coerce" arrays to a common type. This can sometimes solve
type-stability problems without requiring that one copy the data.
