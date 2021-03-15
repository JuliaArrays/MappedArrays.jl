module MappedArrays

using Base: @propagate_inbounds

export AbstractMappedArray, MappedArray, ReadonlyMappedArray, mappedarray, of_eltype

using Reexport
include("ProductedArrays.jl")
@reexport using .ProductedArrays

abstract type AbstractMappedArray{T,N} <: AbstractArray{T,N} end
abstract type AbstractMultiMappedArray{T,N} <: AbstractMappedArray{T,N} end

struct ReadonlyMappedArray{T,N,A<:AbstractArray,F} <: AbstractMappedArray{T,N}
    f::F
    data::A
end
struct MappedArray{T,N,A<:AbstractArray,F,Finv} <: AbstractMappedArray{T,N}
    f::F
    finv::Finv
    data::A
end
struct ReadonlyMultiMappedArray{T,N,AAs<:Tuple{Vararg{AbstractArray}},F} <: AbstractMultiMappedArray{T,N}
    f::F
    data::AAs

    function ReadonlyMultiMappedArray{T,N,AAs,F}(f, data) where {T,N,AAs,F}
        inds = axes(first(data))
        checkinds(inds, Base.tail(data)...)
        new(f, data)
    end
end
struct MultiMappedArray{T,N,AAs<:Tuple{Vararg{AbstractArray}},F,Finv} <: AbstractMultiMappedArray{T,N}
    f::F
    finv::Finv
    data::AAs

    function MultiMappedArray{T,N,AAs,F,Finv}(f::F, finv::Finv, data) where {T,N,AAs,F,Finv}
        inds = axes(first(data))
        checkinds(inds, Base.tail(data)...)
        new(f, finv, data)
    end
end

@inline function checkinds(inds, A, As...)
    @noinline throw1(i, j) = throw(DimensionMismatch("arrays do not all have the same axes (got $i and $j)"))
    iA = axes(A)
    iA == inds || throw1(inds, iA)
    checkinds(inds, As...)
end
checkinds(inds) = nothing

"""
    M = mappedarray(f, A)
    M = mappedarray(f, A, B, C...)

Create a view `M` of the array `A` that applies `f` to every element
of `A`; `M == map(f, A)`, with the difference that no storage
is allocated for `M`. The view is read-only (you can get values but
not set them).

When multiple input arrays are supplied, `M[i] = f(A[i], B[i], C[i]...)`.
"""
function mappedarray(f, data::AbstractArray)
    T = typeof(f(testvalue(data)))
    ReadonlyMappedArray{T,ndims(data),typeof(data),typeof(f)}(f, data)
end

function mappedarray(::Type{T}, data::AbstractArray) where T
    ReadonlyMappedArray{T,ndims(data),typeof(data),Type{T}}(T, data)
end

function mappedarray(f, data::AbstractArray...)
    T = typeof(f(map(testvalue, data)...))
    ReadonlyMultiMappedArray{T,ndims(first(data)),typeof(data),typeof(f)}(f, data)
end

function mappedarray(::Type{T}, data::AbstractArray...) where T
    ReadonlyMultiMappedArray{T,ndims(first(data)),typeof(data),Type{T}}(T, data)
end

"""
    M = mappedarray(f, finv, A)
    M = mappedarray(f, finv, A, B, C...)

creates a view of the array `A` that applies `f` to every element of
`A`. The inverse function, `finv`, allows one to also set values of
the view and, correspondingly, the values in `A`.

When multiple input arrays are supplied, `M[i] = f(A[i], B[i], C[i]...)`.
"""
function mappedarray(f, finv, data::AbstractArray)
    T = typeof(f(testvalue(data)))
    MappedArray{T,ndims(data),typeof(data),typeof(f),typeof(finv)}(f, finv, data)
end

function mappedarray(f, finv, data::AbstractArray...)
    T = typeof(f(map(testvalue, data)...))
    MultiMappedArray{T,ndims(first(data)),typeof(data),typeof(f),typeof(finv)}(f, finv, data)
end

function mappedarray(::Type{T}, finv, data::AbstractArray...) where T
    MultiMappedArray{T,ndims(first(data)),typeof(data),Type{T},typeof(finv)}(T, finv, data)
end
function mappedarray(f, ::Type{Finv}, data::AbstractArray...) where Finv
    T = typeof(f(map(testvalue, data)...))
    MultiMappedArray{T,ndims(first(data)),typeof(data),typeof(f),Type{Finv}}(f, Finv, data)
end

function mappedarray(::Type{T}, ::Type{Finv}, data::AbstractArray...) where {T,Finv}
    MultiMappedArray{T,ndims(first(data)),typeof(data),Type{T},Type{Finv}}(T, Finv, data)
end

"""
    M = of_eltype(T, A)
    M = of_eltype(val::T, A)

creates a view of `A` that lazily-converts the element type to `T`.
"""
of_eltype(::Type{T}, data::AbstractArray{S}) where {S,T} = mappedarray(x->convert(T,x), y->convert(S,y), data)
of_eltype(::Type{T}, data::AbstractArray{T}) where {T} = data
of_eltype(::T, data::AbstractArray{S}) where {S,T} = of_eltype(T, data)

Base.parent(A::AbstractMappedArray) = A.data
Base.size(A::AbstractMappedArray) = size(A.data)
Base.size(A::AbstractMultiMappedArray) = size(first(A.data))
Base.axes(A::AbstractMappedArray) = axes(A.data)
Base.axes(A::AbstractMultiMappedArray) = axes(first(A.data))
parenttype(::Type{ReadonlyMappedArray{T,N,A,F}}) where {T,N,A,F} = A
parenttype(::Type{MappedArray{T,N,A,F,Finv}}) where {T,N,A,F,Finv} = A
parenttype(::Type{ReadonlyMultiMappedArray{T,N,A,F}}) where {T,N,A,F} = A
parenttype(::Type{MultiMappedArray{T,N,A,F,Finv}}) where {T,N,A,F,Finv} = A
Base.IndexStyle(::Type{MA}) where {MA<:AbstractMappedArray} = IndexStyle(parenttype(MA))
@inline Base.IndexStyle(M::AbstractMultiMappedArray) = IndexStyle(M.data...)
Base.IndexStyle(::Type{MA}) where {MA<:AbstractMultiMappedArray} = _indexstyle(MA)
Base.@pure _indexstyle(::Type{MA}) where {MA<:AbstractMultiMappedArray} =
    _indexstyle(map(IndexStyle, parenttype(MA).parameters)...)
_indexstyle(a, b, c...) = _indexstyle(IndexStyle(a, b), c...)
_indexstyle(a, b) = IndexStyle(a, b)


# IndexLinear implementations
@propagate_inbounds Base.getindex(A::AbstractMappedArray, i::Int) =
    A.f(A.data[i])
@propagate_inbounds Base.getindex(M::AbstractMultiMappedArray, i::Int) =
    M.f(_getindex(i, M.data...)...)

@propagate_inbounds function Base.setindex!(A::MappedArray{T},
                                            val,
                                            i::Int) where {T}
    A.data[i] = A.finv(convert(T, val)::T)
end
@propagate_inbounds function Base.setindex!(A::MultiMappedArray{T},
                                            val,
                                            i::Int) where {T}
    vals = A.finv(convert(T, val)::T)
    _setindex!(A.data, vals, i)
    return vals
end


# IndexCartesian implementations
@propagate_inbounds function Base.getindex(A::AbstractMappedArray{T,N},
                                           i::Vararg{Int,N}) where {T,N}
    A.f(A.data[i...])
end
@propagate_inbounds function Base.getindex(A::AbstractMultiMappedArray{T,N},
                                           i::Vararg{Int,N}) where {T,N}
    A.f(_getindex(CartesianIndex(i), A.data...)...)
end

@propagate_inbounds function Base.setindex!(A::MappedArray{T,N},
                                            val,
                                            i::Vararg{Int,N}) where {T,N}
    A.data[i...] = A.finv(convert(T, val)::T)
end
@propagate_inbounds function Base.setindex!(A::MultiMappedArray{T,N},
                                            val,
                                            i::Vararg{Int,N}) where {T,N}
    vals = A.finv(convert(T, val)::T)
    _setindex!(A.data, vals, i...)
    return vals
end


@propagate_inbounds _getindex(i, A, As...) = (A[i], _getindex(i, As...)...)
_getindex(i) = ()

@propagate_inbounds function _setindex!(as::As, vals::Vs, inds::Vararg{Int,N}) where {As,Vs,N}
    a1, atail = as[1], Base.tail(as)
    v1, vtail = vals[1], Base.tail(vals)
    a1[inds...] = v1
    return _setindex!(atail, vtail, inds...)
end
_setindex!(as::Tuple{}, vals::Tuple{}, inds::Vararg{Int,N}) where N = nothing


function testvalue(data)
    if !isempty(data)
        first(data)
    else
        zero(eltype(data))
    end::eltype(data)
end

## Display

function Base.showarg(io::IO, A::AbstractMappedArray{T,N}, toplevel=false) where {T,N}
    print(io, "mappedarray(")
    func_print(io, A.f, eltypes(A.data))
    if isa(A, Union{MappedArray,MultiMappedArray})
        print(io, ", ")
        func_print(io, A.finv, Tuple{T})
    end
    if isa(A, AbstractMultiMappedArray)
        for a in A.data
            print(io, ", ")
            Base.showarg(io, a, false)
        end
    else
        print(io, ", ")
        Base.showarg(io, A.data, false)
    end
    print(io, ')')
    toplevel && print(io, " with eltype ", T)
end

function func_print(io, f, types)
    ft = typeof(f)
    mt = ft.name.mt
    name = string(mt.name)
    if startswith(name, '#')
        # This is an anonymous function. See if it can be printed nicely
        lwrds = code_lowered(f, types)
        if length(lwrds) != 1
            show(io, f)
            return nothing
        end
        lwrd = lwrds[1]
        c = lwrd.code
        if length(c) == 2 && ((isa(c[2], Expr) && c[2].head === :return) || (isdefined(Core, :ReturnNode) && isa(c[2], Core.ReturnNode)))
            # This is a single-line anonymous function, we should handle it
            s = lwrd.slotnames[2:end]
            if length(s) == 1
                print(io, s[1], "->")
            else
                print(io, tuple(s...), "->")
            end
            c1 = string(c[1])
            for i = 1:length(s)
                c1 = replace(c1, "_"*string(i+1)=>string(s[i]))
            end
            print(io, c1)
        else
            show(io, f)
        end
    else
        show(io, f)
    end
end

eltypes(A::AbstractArray) = Tuple{eltype(A)}
@Base.pure eltypes(A::Tuple{Vararg{<:AbstractArray}}) = Tuple{(eltype.(A))...}

## Deprecations
@deprecate mappedarray(f_finv::Tuple{Any,Any}, args::AbstractArray...) mappedarray(f_finv[1], f_finv[2], args...)

end # module
