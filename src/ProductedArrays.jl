module ProductedArrays
    export ProductedArray

    struct ProductedArray{T, N, AAs<:Tuple{Vararg{AbstractArray}}} <: AbstractArray{T, N}
        data::AAs
    end
    function ProductedArray(data...)
        ProductedArray{typeof(map(first, data)), mapreduce(ndims, +, data), typeof(data)}(data)
    end

    @inline Base.size(A::ProductedArray) = mapreduce(size, (i,j)->(i...,j...), A.data)

    Base.@propagate_inbounds function Base.getindex(A::ProductedArray{T, N}, inds::Vararg{Int, N}) where {T, N}
        map((x, i)->x[i...], A.data, _split_indices(A, inds))
    end

    # TODO: this fails to inline and thus gives about 1.5ns overhead to getindex
    @inline function _split_indices(A::ProductedArray{T, N}, inds::NTuple{N, Int}) where {T, N}
        # TODO: this line is repeatedly computed
        pos = (firstindex(A.data)-1, accumulate(+, map(ndims, A.data))...)

        return ntuple(i->inds[pos[i]+1:pos[i+1]], length(pos)-1)
    end
end
