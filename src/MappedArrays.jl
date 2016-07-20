module MappedArrays

using Base: @propagate_inbounds

export mappedarray

abstract AbstractMappedArray{T,N} <: AbstractArray{T,N}

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
mappedarray{T,N}(f, data::AbstractArray{T,N}) = ReadonlyMappedArray{typeof(f(one(T))),N,typeof(data),typeof(f)}(f, data)

"""
    mappedarray((f, finv), A)

creates a view of the array `A` that applies `f` to every element of
`A`. The inverse function, `finv`, allows one to also set values of
the view and, correspondingly, the values in `A`.
"""
function mappedarray{T,N}(f_finv::Tuple{Any,Any}, data::AbstractArray{T,N})
    f, finv = f_finv
    MappedArray{typeof(f(one(T))),N,typeof(data),typeof(f),typeof(finv)}(f, finv, data)
end

Base.parent(A::AbstractMappedArray) = A.data
Base.size(A::AbstractMappedArray) = size(A.data)
parenttype{T,N,A,F}(::Type{ReadonlyMappedArray{T,N,A,F}}) = A
parenttype{T,N,A,F,Finv}(::Type{MappedArray{T,N,A,F,Finv}}) = A
Base.linearindexing{MA<:AbstractMappedArray}(::Type{MA}) = Base.linearindexing(parenttype(MA))

@propagate_inbounds Base.getindex(A::AbstractMappedArray, i::Int...) = A.f(A.data[i...])
@propagate_inbounds Base.setindex!(A::MappedArray, val, i::Int...) = A.data[i...] = A.finv(val)

end # module
