__precompile__()

module MappedArrays

using Base: @propagate_inbounds

export AbstractMappedArray, MappedArray, ReadonlyMappedArray, mappedarray, of_eltype

abstract type AbstractMappedArray{T,N} <: AbstractArray{T,N} end

struct ReadonlyMappedArray{T,N,A<:AbstractArray,F} <: AbstractMappedArray{T,N}
    f::F
    data::A
end
struct MappedArray{T,N,A<:AbstractArray,F,Finv} <: AbstractMappedArray{T,N}
    f::F
    finv::Finv
    data::A
end
struct ReadonlyMultiMappedArray{T,N,AAs<:Tuple{Vararg{AbstractArray}},F} <: AbstractMappedArray{T,N}
    f::F
    data::AAs

    function ReadonlyMultiMappedArray{T,N,AAs,F}(f, data) where {T,N,AAs,F}
        inds = indices(first(data))
        checkinds(inds, Base.tail(data)...)
        new(f, data)
    end
end

# TODO: remove @inline for 0.7
@inline function checkinds(inds, A, As...)
    @noinline throw1(i, j) = throw(DimensionMismatch("arrays do not all have the same indices (got $i and $j)"))
    iA = indices(A)
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
mappedarray(f, data::AbstractArray{T,N}) where {T,N} = ReadonlyMappedArray{typeof(f(testvalue(data))),N,typeof(data),typeof(f)}(f, data)

mappedarray(f, data::AbstractArray...) = ReadonlyMultiMappedArray{typeof(f(map(testvalue, data)...)),ndims(first(data)),typeof(data),typeof(f)}(f, data)

"""
    mappedarray((f, finv), A)

creates a view of the array `A` that applies `f` to every element of
`A`. The inverse function, `finv`, allows one to also set values of
the view and, correspondingly, the values in `A`.
"""
function mappedarray(f_finv::Tuple{Any,Any}, data::AbstractArray{T,N}) where {T,N}
    f, finv = f_finv
    MappedArray{typeof(f(testvalue(data))),N,typeof(data),typeof(f),typeof(finv)}(f, finv, data)
end

"""
    of_eltype(T, A)
    of_eltype(val::T, A)

creates a view of `A` that lazily-converts the element type to `T`.
"""
of_eltype(::Type{T}, data::AbstractArray{S}) where {S,T} = mappedarray((x->convert(T,x), y->convert(S,y)), data)
of_eltype(::Type{T}, data::AbstractArray{T}) where {T} = data
of_eltype(::T, data::AbstractArray{S}) where {S,T} = of_eltype(T, data)

Base.parent(A::AbstractMappedArray) = A.data
Base.size(A::AbstractMappedArray) = size(A.data)
Base.size(A::ReadonlyMultiMappedArray) = size(first(A.data))
Base.indices(A::AbstractMappedArray) = indices(A.data)
Base.indices(A::ReadonlyMultiMappedArray) = indices(first(A.data))
parenttype(::Type{ReadonlyMappedArray{T,N,A,F}}) where {T,N,A,F} = A
parenttype(::Type{MappedArray{T,N,A,F,Finv}}) where {T,N,A,F,Finv} = A
parenttype(::Type{ReadonlyMultiMappedArray{T,N,A,F}}) where {T,N,A,F} = A
Base.IndexStyle(::Type{MA}) where {MA<:AbstractMappedArray} = IndexStyle(parenttype(MA))
Base.@pure Base.IndexStyle(::Type{MA}) where {MA<:ReadonlyMultiMappedArray} = _indexstyle(map(IndexStyle, parenttype(MA).parameters)...)
_indexstyle(a, b, c...) = _indexstyle(IndexStyle(a, b), c...)
_indexstyle(a, b) = IndexStyle(a, b)


# IndexLinear implementations
@propagate_inbounds Base.getindex(A::AbstractMappedArray, i::Int) =
    A.f(A.data[i])
@propagate_inbounds Base.getindex(M::ReadonlyMultiMappedArray, i::Int) =
    M.f(map(A->A[i], M.data)...)
@propagate_inbounds function Base.setindex!(A::MappedArray{T},
                                            val::T,
                                            i::Int) where {T}
    A.data[i] = A.finv(val)
end
@inline function Base.setindex!(A::MappedArray{T},
                                val, i::Int) where {T}
    setindex!(A, convert(T, val), i)
end

# IndexCartesian implementations
@propagate_inbounds function Base.getindex(A::AbstractMappedArray{T,N},
                                           i::Vararg{Int,N}) where {T,N}
    A.f(A.data[i...])
end
@propagate_inbounds function Base.getindex(M::ReadonlyMultiMappedArray{T,N},
                                           i::Vararg{Int,N}) where {T,N}
    M.f(map(A->A[i...], M.data)...)
end
@propagate_inbounds function Base.setindex!(A::MappedArray{T,N},
                                            val::T,
                                            i::Vararg{Int,N}) where {T,N}
    A.data[i...] = A.finv(val)
end
@inline function Base.setindex!(A::MappedArray{T,N},
                                val, i::Vararg{Int,N}) where {T,N}
    setindex!(A, convert(T, val), i...)
end

function testvalue(data)
    if !isempty(data)
        first(data)
    else
        zero(eltype(data))
    end::eltype(data)
end

end # module
