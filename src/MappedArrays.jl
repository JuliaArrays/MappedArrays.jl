module MappedArrays

using Base: @propagate_inbounds

export mappedarray

abstract AbstractMappedArray{T,N} <: AbstractArray{T,N}

immutable ReadonlyMappedArray{T,N,A<:AbstractArray,F} <: AbstractMappedArray{T,N}
    data::A
    f::F
end
immutable MappedArray{T,N,A<:AbstractArray,F,Finv} <: AbstractMappedArray{T,N}
    data::A
    f::F
    finv::Finv
end

mappedarray{T,N}(data::AbstractArray{T,N}, f) = ReadonlyMappedArray{typeof(f(one(T))),N,typeof(data),typeof(f)}(data, f)
mappedarray{T,N}(data::AbstractArray{T,N}, f, finv) = MappedArray{typeof(f(one(T))),N,typeof(data),typeof(f),typeof(finv)}(data, f, finv)

Base.parent(A::AbstractMappedArray) = A.data
Base.size(A::AbstractMappedArray) = size(A.data)
parenttype{T,N,A,F}(::Type{ReadonlyMappedArray{T,N,A,F}}) = A
parenttype{T,N,A,F,Finv}(::Type{MappedArray{T,N,A,F,Finv}}) = A
Base.linearindexing{MA<:AbstractMappedArray}(::Type{MA}) = Base.linearindexing(parenttype(MA))

@propagate_inbounds Base.getindex(A::AbstractMappedArray, i::Int...) = A.f(A.data[i...])
@propagate_inbounds Base.setindex!(A::MappedArray, val, i::Int...) = A.data[i...] = A.finv(val)

end # module
