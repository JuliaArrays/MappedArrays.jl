__precompile__()

module MappedArrays

using Base: @propagate_inbounds
using Compat

export AbstractMappedArray, MappedArray, ReadonlyMappedArray, mappedarray, of_eltype

@compat abstract type AbstractMappedArray{T,N} <: AbstractArray{T,N} end

immutable ReadonlyMappedArray{T,N,A<:AbstractArray,F} <: AbstractMappedArray{T,N}
    f::F
    data::A
end
immutable MappedArray{T,N,A<:AbstractArray,F,Finv} <: AbstractMappedArray{T,N}
    f::F
    finv::Finv
    data::A
end

"""
     mappedarray(f, A)

creates a view of the array `A` that applies `f` to every element of
`A`. The view is read-only (you can get values but not set them).
"""
mappedarray{T,N}(f, data::AbstractArray{T,N}) = ReadonlyMappedArray{typeof(f(testvalue(data))),N,typeof(data),typeof(f)}(f, data)

"""
    mappedarray((f, finv), A)

creates a view of the array `A` that applies `f` to every element of
`A`. The inverse function, `finv`, allows one to also set values of
the view and, correspondingly, the values in `A`.
"""
function mappedarray{T,N}(f_finv::Tuple{Any,Any}, data::AbstractArray{T,N})
    f, finv = f_finv
    MappedArray{typeof(f(testvalue(data))),N,typeof(data),typeof(f),typeof(finv)}(f, finv, data)
end

"""
    of_eltype(T, A)
    of_eltype(val::T, A)

creates a view of `A` that lazily-converts the element type to `T`.
"""
of_eltype{S,T}(::Type{T}, data::AbstractArray{S}) = mappedarray((x->convert(T,x), y->convert(S,y)), data)
of_eltype{T}(::Type{T}, data::AbstractArray{T}) = data
of_eltype{S,T}(::T, data::AbstractArray{S}) = of_eltype(T, data)

Base.parent(A::AbstractMappedArray) = A.data
Base.size(A::AbstractMappedArray) = size(A.data)
Base.indices(A::AbstractMappedArray) = indices(A.data)
parenttype{T,N,A,F}(::Type{ReadonlyMappedArray{T,N,A,F}}) = A
parenttype{T,N,A,F,Finv}(::Type{MappedArray{T,N,A,F,Finv}}) = A
@compat Base.IndexStyle{MA<:AbstractMappedArray}(::Type{MA}) = IndexStyle(parenttype(MA))

@propagate_inbounds Base.getindex(A::AbstractMappedArray, i::Int...) = A.f(A.data[i...])
@propagate_inbounds Base.setindex!{T}(A::MappedArray{T}, val::T, i::Int...) = A.data[i...] = A.finv(val)
@inline Base.setindex!{T}(A::MappedArray{T}, val, i::Int...) = setindex!(A, convert(T, val), i...)

function testvalue(data)
    if !isempty(data)
        return first(data)
    end
    zero(eltype(data))
end

end # module
