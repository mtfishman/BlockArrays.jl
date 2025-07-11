module BlockArrays
using LinearAlgebra, ArrayLayouts, FillArrays

# AbstractBlockArray interface exports
export AbstractBlockArray, AbstractBlockMatrix, AbstractBlockVector, AbstractBlockVecOrMat
export Block, getblock, getblock!, setblock!, eachblock, blocks
export blockaxes, blocksize, blocklength, blockcheckbounds, BlockBoundsError, BlockIndex, BlockIndexRange
export blocksizes, blocklengths, blocklasts, blockfirsts, blockisequal, blockequals, blockisapprox
export eachblockaxes
export BlockRange, blockedrange, BlockedUnitRange, BlockedOneTo

export BlockArray, BlockMatrix, BlockVector, BlockVecOrMat, mortar
export BlockedArray, BlockedMatrix, BlockedVector, BlockedVecOrMat

export undef_blocks, undef, findblock, findblockindex

export khatri_rao, blockkron, BlockKron

export blockappend!, blockpush!, blockpushfirst!, blockpop!, blockpopfirst!

import Base: @propagate_inbounds, Array, AbstractArray, to_indices, to_index,
            unsafe_indices, first, last, size, length, unsafe_length,
            unsafe_convert,
            getindex, setindex!, ndims, show, print_array, view,
            step,
            broadcast, eltype, convert, similar, collect,
            tail, reindex,
            RangeIndex, Int, Integer, Number, Tuple,
            +, -, *, /, \, min, max, isless, in, copy, copyto!, axes, @deprecate,
            BroadcastStyle, checkbounds, checkindex, ensure_indexable,
            oneunit, ones, zeros, intersect, Slice, resize!

using Base: ReshapedArray, LogicalIndex, dataids, oneto

import Base: (:), IteratorSize, iterate, axes1, strides, isempty
import Base.Broadcast: broadcasted, DefaultArrayStyle, AbstractArrayStyle, Broadcasted, broadcastable

import ArrayLayouts: MatLdivVec, MatLmulVec, MatMulMatAdd, MatMulVecAdd, MemoryLayout, _copyto!, _inv, colsupport,
                     conjlayout, rowsupport, sub_materialize, sub_materialize_axes, sublayout, transposelayout,
                     triangulardata, triangularlayout, zero!, materialize!

import FillArrays: axes_print_matrix_row

import LinearAlgebra: AbstractTriangular, AdjOrTrans, HermOrSym, RealHermSymComplexHerm, StructuredMatrixStyle,
                      lmul!, rmul!


if VERSION ≥ v"1.11.0-DEV.21"
    using LinearAlgebra: UpperOrLowerTriangular
else
    const UpperOrLowerTriangular{T,S} = Union{LinearAlgebra.UpperTriangular{T,S},
                                              LinearAlgebra.UnitUpperTriangular{T,S},
                                              LinearAlgebra.LowerTriangular{T,S},
                                              LinearAlgebra.UnitLowerTriangular{T,S}}
end

_maybetail(::Tuple{}) = ()
_maybetail(t::Tuple) = tail(t)

include("blockindices.jl")
include("blockaxis.jl")
include("abstractblockarray.jl")
include("blockarray.jl")
include("blockedarray.jl")
include("views.jl")
include("blocks.jl")

include("blockbroadcast.jl")
include("blockcholesky.jl")
include("blocklinalg.jl")
include("blockproduct.jl")
include("show.jl")
include("blockreduce.jl")
include("blockdeque.jl")
include("blockarrayinterface.jl")
include("blockbanded.jl")

@deprecate getblock(A::AbstractBlockArray{T,N}, I::Vararg{Integer, N}) where {T,N} view(A, Block(I))
@deprecate getblock!(X, A::AbstractBlockArray{T,N}, I::Vararg{Integer, N}) where {T,N} copyto!(X, view(A, Block(I)))
@deprecate setblock!(A::AbstractBlockArray{T,N}, v, I::Vararg{Integer, N}) where {T,N} (A[Block(I...)] = v)

end # module
