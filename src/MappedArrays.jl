__precompile__()

module MappedArrays

using Base: @propagate_inbounds

export AbstractMappedArray, MappedArray, ReadonlyMappedArray, mappedarray, of_eltype

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

    function MultiMappedArray{T,N,AAs,F,Finv}(f_finv::Tuple{F,Finv}, data) where {T,N,AAs,F,Finv}
        inds = axes(first(data))
        checkinds(inds, Base.tail(data)...)
        f, finv = f_finv
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

function mappedarray(f, data::AbstractArray...)
    T = typeof(f(map(testvalue, data)...))
    ReadonlyMultiMappedArray{T,ndims(first(data)),typeof(data),typeof(f)}(f, data)
end

"""
    M = mappedarray((f, finv), A)
    M = mappedarray((f, finv), A, B, C...)

creates a view of the array `A` that applies `f` to every element of
`A`. The inverse function, `finv`, allows one to also set values of
the view and, correspondingly, the values in `A`.

When multiple input arrays are supplied, `M[i] = f(A[i], B[i], C[i]...)`.
"""
function mappedarray(f_finv::Tuple{Any,Any}, data::AbstractArray)
    f, finv = f_finv
    T = typeof(f(testvalue(data)))
    MappedArray{T,ndims(data),typeof(data),typeof(f),typeof(finv)}(f, finv, data)
end

function mappedarray(f_finv::Tuple{Any,Any}, data::AbstractArray...)
    f, finv = f_finv
    T = typeof(f(map(testvalue, data)...))
    MultiMappedArray{T,ndims(first(data)),typeof(data),typeof(f),typeof(finv)}(f_finv, data)
end

"""
    M = of_eltype(T, A)
    M = of_eltype(val::T, A)

creates a view of `A` that lazily-converts the element type to `T`.
"""
of_eltype(::Type{T}, data::AbstractArray{S}) where {S,T} = mappedarray((x->convert(T,x), y->convert(S,y)), data)
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
@inline @propagate_inbounds Base.getindex(A::AbstractMappedArray, i::Int) =
    A.f(A.data[i])
@inline @propagate_inbounds Base.getindex(M::AbstractMultiMappedArray, i::Int) =
    M.f(_getindex(i, M.data...)...)

@inline @propagate_inbounds function Base.setindex!(A::MappedArray{T},
                                                    val,
                                                    i::Int) where {T}
    A.data[i] = A.finv(convert(T, val)::T)
end
@inline @propagate_inbounds function Base.setindex!(A::MultiMappedArray{T},
                                                    val,
                                                    i::Int) where {T}
    vals = A.finv(convert(T, val)::T)
    _setindex!(A.data, vals, i)
    return vals
end


# IndexCartesian implementations
@inline @propagate_inbounds function Base.getindex(A::AbstractMappedArray{T,N},
                                                   i::Vararg{Int,N}) where {T,N}
    A.f(A.data[i...])
end
@inline @propagate_inbounds function Base.getindex(M::AbstractMultiMappedArray{T,N},
                                                   i::Vararg{Int,N}) where {T,N}
    M.f(_getindex(CartesianIndex(i), M.data...)...)
end

@inline @propagate_inbounds function Base.setindex!(A::MappedArray{T,N},
                                                    val,
                                                    i::Vararg{Int,N}) where {T,N}
    A.data[i...] = A.finv(convert(T, val)::T)
end
@inline @propagate_inbounds function Base.setindex!(A::MultiMappedArray{T,N},
                                                    val,
                                                    i::Vararg{Int,N}) where {T,N}
    vals = A.finv(convert(T, val)::T)
    _setindex!(A.data, vals, i...)
    return vals
end


@inline @propagate_inbounds _getindex(i, A, As...) = (A[i], _getindex(i, As...)...)
_getindex(i) = ()

@inline @propagate_inbounds function _setindex!(as::As, vals::Vs, inds::Vararg{Int,N}) where {As,Vs,N}
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

end # module
