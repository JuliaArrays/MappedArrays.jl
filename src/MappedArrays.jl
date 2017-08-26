__precompile__()

module MappedArrays

using Base: @propagate_inbounds
using Compat

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

"""
     mappedarray(f, A)

creates a view of the array `A` that applies `f` to every element of
`A`. The view is read-only (you can get values but not set them).
"""
mappedarray(f, data::AbstractArray{T,N}) where {T,N} = ReadonlyMappedArray{typeof(f(testvalue(data))),N,typeof(data),typeof(f)}(f, data)

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
Base.indices(A::AbstractMappedArray) = indices(A.data)
parenttype(::Type{ReadonlyMappedArray{T,N,A,F}}) where {T,N,A,F} = A
parenttype(::Type{MappedArray{T,N,A,F,Finv}}) where {T,N,A,F,Finv} = A
Base.IndexStyle(::Type{MA}) where {MA<:AbstractMappedArray} = IndexStyle(parenttype(MA))

@propagate_inbounds Base.getindex(A::AbstractMappedArray, i::Int...) = A.f(A.data[i...])
@propagate_inbounds Base.setindex!(A::MappedArray{T}, val::T, i::Int...) where {T} = A.data[i...] = A.finv(val)
@inline Base.setindex!(A::MappedArray{T}, val, i::Int...) where {T} = setindex!(A, convert(T, val), i...)

function testvalue(data)
    if !isempty(data)
        first(data)
    else
        zero(eltype(data))
    end::eltype(data)
end

end # module
