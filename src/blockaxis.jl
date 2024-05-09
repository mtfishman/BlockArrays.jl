
# interface

@propagate_inbounds getindex(b::AbstractVector, K::BlockIndex{1}) = b[Block(K.I[1])][K.α[1]]
@propagate_inbounds getindex(b::AbstractArray{T,N}, K::BlockIndex{N}) where {T,N} =
    b[block(K)][K.α...]
@propagate_inbounds getindex(b::AbstractArray, K::BlockIndex{1}, J::BlockIndex{1}...) =
    b[BlockIndex(tuple(K, J...))]

@propagate_inbounds getindex(b::AbstractArray{T,N}, K::BlockIndexRange{N}) where {T,N} = b[block(K)][K.indices...]
@propagate_inbounds getindex(b::LayoutArray{T,N}, K::BlockIndexRange{N}) where {T,N} = b[block(K)][K.indices...]
@propagate_inbounds getindex(b::LayoutArray{T,1}, K::BlockIndexRange{1}) where {T} = b[block(K)][K.indices...]

function findblockindex(b::AbstractVector, k::Integer)
    @boundscheck k in b || throw(BoundsError())
    bl = blocklasts(b)
    blockidx = _searchsortedfirst(bl, k)
    @assert blockindex != lastindex(bl) + 1 # guaranteed by the @boundscheck above
    prevblocklast = blockidx == firstindex(bl) ? first(b)-oneunit(eltype(b)) : bl[blockidx-1]
    local_index = k - prevblocklast
    return BlockIndex(blockidx, local_index)
end

abstract type AbstractBlockedUnitRange{T,CS} <: AbstractUnitRange{T} end

function _BlockedUnitRange end


"""
    BlockedUnitRange

is an `AbstractUnitRange{Int}` that has been divided into blocks.
Construction is typically via `blockedrange` which converts
a vector of block lengths to a `BlockedUnitRange`.

# Examples
```jldoctest
julia> blockedrange(2, [2,2,3]) # first value and block lengths
3-blocked 7-element BlockedUnitRange{Int64, Vector{Int64}}:
 2
 3
 ─
 4
 5
 ─
 6
 7
 8
```

See also [`BlockedOneTo`](@ref).
"""
struct BlockedUnitRange{T<:Integer,CS} <: AbstractBlockedUnitRange{T,CS}
    first::T
    lasts::CS
    # assume that lasts is sorted, no checks carried out here
    global function _BlockedUnitRange(f::T, cs::CS) where {T,CS<:AbstractVector{T}}
        Base.require_one_based_indexing(cs)
        return new{T,CS}(f, cs)
    end
    global function _BlockedUnitRange(f::T, cs::CS) where {T,CS<:Tuple{T,Vararg{T}}}
        return new{T,CS}(f, cs)
    end
    global function _BlockedUnitRange(f::T, cs::Tuple{}) where {T}
        return new{T,Tuple{}}(f, cs)
    end
end

@inline function _BlockedUnitRange(f::T, cs::AbstractVector{S}) where {T,S}
  U = promote_type(T, S)
  return _BlockedUnitRange(convert(U, f), convert.(U, cs))
end
@inline function _BlockedUnitRange(f::T, cs::Tuple{S,Vararg{S}}) where {T,S}
  U = promote_type(T, S)
  return _BlockedUnitRange(convert(U, f), convert.(U, cs))
end
@inline function _BlockedUnitRange(f, cs::Tuple)
  return _BlockedUnitRange(f, promote(cs...))
end
@inline _BlockedUnitRange(cs::AbstractVector) = _BlockedUnitRange(oneunit(eltype(cs)), cs)
@inline _BlockedUnitRange(cs::NTuple) = _BlockedUnitRange(oneunit(eltype(cs)), cs)
_BlockedUnitRange(cs::Tuple) = _BlockedUnitRange(promote(cs...))

first(b::BlockedUnitRange) = b.first
@inline blocklasts(a::BlockedUnitRange) = a.lasts

BlockedUnitRange(::BlockedUnitRange) = throw(ArgumentError("Forbidden due to ambiguity"))
# Use `accumulate` instead of `cumsum` because it preserves the element type of the block lengths
_blocklengths2blocklasts(blocks) = accumulate(+, blocks) # extra level to allow changing default accumulate behaviour

@inline blockfirsts(a::AbstractBlockedUnitRange) = [first(a); @views(blocklasts(a)[1:end-1]) .+ oneunit(eltype(a))]

# optimize common cases
@inline function blockfirsts(a::AbstractBlockedUnitRange{<:Any,<:Union{Vector, RangeCumsum{<:Any, <:UnitRange}}})
    v = Vector{eltype(a)}(undef, length(blocklasts(a)))
    v[1] = first(a)
    v[2:end] .= @views(blocklasts(a)[oneto(end-1)]) .+ oneunit(eltype(a))
    return v
end
@inline function blockfirsts(a::AbstractBlockedUnitRange{<:Any,<:Tuple})
    return (first(a), (blocklasts(a)[oneto(end-1)] .+ oneunit(eltype(a)))...)
end

"""
    BlockedOneTo{T, <:Union{AbstractVector{T}, NTuple{<:Any,T}}} where {T}

Define an `AbstractUnitRange{T}` that has been divided
into blocks, which is used to represent `axes` of block arrays.
This parallels `Base.OneTo` in that the first value is guaranteed
to be `1`.

Construction is typically via `blockedrange` which converts
a vector of block lengths to a `BlockedUnitRange`.

# Examples
```jldoctest
julia> blockedrange([2,2,3]) # block lengths
3-blocked 7-element BlockedOneTo{Int64, Vector{Int64}}:
 1
 2
 ─
 3
 4
 ─
 5
 6
 7
```

See also [`BlockedUnitRange`](@ref).
"""
struct BlockedOneTo{T<:Integer,CS} <: AbstractBlockedUnitRange{T,CS}
    lasts::CS
    # assume that lasts is sorted, no checks carried out here
    function BlockedOneTo(lasts::CS) where {T<:Integer, CS<:AbstractVector{T}}
        _throw_if_bool(T)
        Base.require_one_based_indexing(lasts)
        isempty(lasts) || first(lasts) >= 0 || throw(ArgumentError("blocklasts must be >= 0"))
        new{T,CS}(lasts)
    end
    function BlockedOneTo(lasts::CS) where {T<:Integer, CS<:Tuple{T,Vararg{T}}}
        _throw_if_bool(T)
        first(lasts) >= 0 || throw(ArgumentError("blocklasts must be >= 0"))
        new{T,CS}(lasts)
    end
end
_throw_if_bool(_) = nothing
_throw_if_bool(::Type{Bool}) = throw(ArgumentError("a Bool collection is not allowed as blocklasts"))

const DefaultBlockAxis = BlockedOneTo{Int, Vector{Int}}

first(b::BlockedOneTo) = oneunit(eltype(b))
@inline blocklasts(a::BlockedOneTo) = a.lasts

BlockedOneTo(::BlockedOneTo) = throw(ArgumentError("Forbidden due to ambiguity"))

axes(b::BlockedOneTo) = (b,)

"""
    blockedrange(blocklengths::Union{Tuple, AbstractVector})
    blockedrange(first::Int, blocklengths::Union{Tuple, AbstractVector})

Return a blocked `AbstractUnitRange{Int}` with the block sizes being `blocklengths`.
If `first` is provided, this is used as the first value of the range.
Otherwise, if only the block lengths are provided, `first` is assumed to be `1`.

# Examples
```jldoctest
julia> blockedrange([1,2])
2-blocked 3-element BlockedOneTo{Int64, Vector{Int64}}:
 1
 ─
 2
 3

julia> blockedrange(2, (1,2))
2-blocked 3-element BlockedUnitRange{Int64, Tuple{Int64, Int64}}:
 2
 ─
 3
 4
```
"""
@inline blockedrange(blocks::Union{Tuple,AbstractVector}) = BlockedOneTo(_blocklengths2blocklasts(blocks))
@inline blockedrange(f::Integer, blocks::Union{Tuple,AbstractVector}) = _BlockedUnitRange(f, f-oneunit(f) .+ _blocklengths2blocklasts(blocks))

_diff(a::AbstractVector) = diff(a)
_diff(a::Tuple) = diff(collect(a))
@inline _blocklengths(a, bl, dbl) = isempty(bl) ? [dbl;] : [first(bl)-first(a)+oneunit(eltype(a)); dbl]
@inline function _blocklengths(a::BlockedOneTo, bl::RangeCumsum, ::OrdinalRange)
    # the 1:0 is hardcoded here to enable conversions to a Base.OneTo
    isempty(bl) ? oftype(bl.range, 1:0) : bl.range
end
@inline _blocklengths(a, bl) = _blocklengths(a, bl, _diff(bl))
@inline blocklengths(a::AbstractBlockedUnitRange) = _blocklengths(a, blocklasts(a))

length(a::AbstractBlockedUnitRange) = isempty(blocklasts(a)) ? zero(eltype(a)) : Integer(last(blocklasts(a))-first(a)+oneunit(eltype(a)))

"""
    blockisequal(a::AbstractUnitRange{Int}, b::AbstractUnitRange{Int})

Check if `a` and `b` have the same block structure.

# Examples
```jldoctest
julia> b1 = blockedrange([1,2])
2-blocked 3-element BlockedOneTo{Int64, Vector{Int64}}:
 1
 ─
 2
 3

julia> b2 = blockedrange([1,1,1])
3-blocked 3-element BlockedOneTo{Int64, Vector{Int64}}:
 1
 ─
 2
 ─
 3

julia> blockisequal(b1, b1)
true

julia> blockisequal(b1, b2)
false
```
"""
blockisequal(a::AbstractUnitRange{Int}, b::AbstractUnitRange{Int}) = first(a) == first(b) && blocklasts(a) == blocklasts(b)
blockisequal(a, b, c, d...) = blockisequal(a,b) && blockisequal(b,c,d...)
"""
    blockisequal(a::Tuple, b::Tuple)

Return if the tuples satisfy `blockisequal` elementwise.
"""
blockisequal(a::Tuple, b::Tuple) = blockisequal(first(a), first(b)) && blockisequal(Base.tail(a), Base.tail(b))
blockisequal(::Tuple{}, ::Tuple{}) = true
blockisequal(::Tuple, ::Tuple{}) = false
blockisequal(::Tuple{}, ::Tuple) = false


_shift_blocklengths(::AbstractBlockedUnitRange, bl, f) = bl
_shift_blocklengths(::Any, bl, f) = bl .+ (f - 1)
const OneBasedRanges = Union{Base.OneTo, Base.Slice{<:Base.OneTo}, Base.IdentityUnitRange{<:Base.OneTo}}
_shift_blocklengths(::OneBasedRanges, bl, f) = bl
function Base.convert(::Type{BlockedUnitRange}, axis::AbstractUnitRange{Int})
    bl = blocklasts(axis)
    f = first(axis)
    _BlockedUnitRange(f, _shift_blocklengths(axis, bl, f))
end
function Base.convert(::Type{BlockedUnitRange{T,CS}}, axis::AbstractUnitRange{Int}) where {T,CS}
    bl = blocklasts(axis)
    f = first(axis)
    _BlockedUnitRange(convert(T, f), convert(CS, _shift_blocklengths(axis, bl, f)))
end

Base.unitrange(b::AbstractBlockedUnitRange) = first(b):last(b)

Base.promote_rule(::Type{<:AbstractBlockedUnitRange{T}}, ::Type{Base.OneTo{Int}}) where {T} = UnitRange{promote_type(T, Int)}

function Base.convert(::Type{BlockedOneTo}, axis::AbstractUnitRange{<:Integer})
    first(axis) == 1 || throw(ArgumentError("first element of range is not 1"))
    BlockedOneTo(blocklasts(axis))
end
function Base.convert(::Type{BlockedOneTo{T, CS}}, axis::AbstractUnitRange{<:Integer}) where {T, CS}
    first(axis) == 1 || throw(ArgumentError("first element of range is not 1"))
    BlockedOneTo(convert(CS, blocklasts(axis)))
end

"""
    blockaxes(A::AbstractArray)

Return the tuple of valid block indices for array `A`.

# Examples
```jldoctest
julia> A = BlockArray([1,2,3],[2,1])
2-blocked 3-element BlockVector{Int64}:
 1
 2
 ─
 3

julia> blockaxes(A)
(BlockRange(Base.OneTo(2)),)

julia> B = BlockArray(zeros(3,4), [1,2], [1,2,1])
2×3-blocked 3×4 BlockMatrix{Float64}:
 0.0  │  0.0  0.0  │  0.0
 ─────┼────────────┼─────
 0.0  │  0.0  0.0  │  0.0
 0.0  │  0.0  0.0  │  0.0

julia> blockaxes(B)
(BlockRange(Base.OneTo(2)), BlockRange(Base.OneTo(3)))
```
"""
blockaxes(b::AbstractBlockedUnitRange) = _blockaxes(blocklasts(b))
_blockaxes(b::AbstractVector) = (Block.(axes(b,1)),)
_blockaxes(b::Tuple) = (Block.(Base.OneTo(length(b))),)
blockaxes(b) = blockaxes.(axes(b), 1)

"""
    blockaxes(A::AbstractArray, d::Int)

Return the valid range of block indices for array `A` along dimension `d`.

# Examples
```jldoctest
julia> A = BlockArray([1,2,3], [2,1])
2-blocked 3-element BlockVector{Int64}:
 1
 2
 ─
 3

julia> blockaxes(A,1)
BlockRange(Base.OneTo(2))

julia> blockaxes(A,1) |> collect
2-element Vector{Block{1, Int64}}:
 Block(1)
 Block(2)
```
"""
@inline function blockaxes(A::AbstractArray{T,N}, d) where {T,N}
    d::Integer <= N ? blockaxes(A)[d] : Base.OneTo(1)
end

"""
    blocksize(A::AbstractArray)
    blocksize(A::AbstractArray, i::Int)

Return the tuple of the number of blocks along each
dimension. See also size and blocksizes.

# Examples
```jldoctest
julia> A = BlockArray(ones(3,3),[2,1],[1,1,1])
2×3-blocked 3×3 BlockMatrix{Float64}:
 1.0  │  1.0  │  1.0
 1.0  │  1.0  │  1.0
 ─────┼───────┼─────
 1.0  │  1.0  │  1.0

julia> blocksize(A)
(2, 3)

julia> blocksize(A,2)
3
```
"""
blocksize(A) = map(length, blockaxes(A))
blocksize(A,i) = length(blockaxes(A,i))
@inline blocklength(t) = prod(blocksize(t))

struct BlockSizes{N,A<:AbstractArray{<:Any,N}} <: AbstractArray{NTuple{N,Int},N}
  array::A
end
Base.size(a::BlockSizes) = blocksize(a.array)
Base.axes(a::BlockSizes) = map(br -> only(br.indices), blockaxes(a.array))
Base.IteratorEltype(::Type{<:BlockSizes}) = Base.EltypeUnknown()
@propagate_inbounds getindex(a::BlockSizes{N}, i::Vararg{Int,N}) where {N} =
    size(view(a.array, Block.(i)...))
@propagate_inbounds function setindex!(a::BlockSizes{N}, b, i::Vararg{Int,N}) where {N}
    error("Not implemented")
end

"""
    blocksizes(A::AbstractArray)

Return an iterator over the sizes of each block.
See also size and blocksize.

# Examples
```jldoctest
julia> A = BlockArray(ones(3,3),[2,1],[1,1,1])
2×3-blocked 3×3 BlockMatrix{Float64}:
 1.0  │  1.0  │  1.0
 1.0  │  1.0  │  1.0
 ─────┼───────┼─────
 1.0  │  1.0  │  1.0

julia> blocksizes(A)
2×3 BlockArrays.BlockSizes{2, BlockMatrix{Float64, Matrix{Matrix{Float64}}, Tuple{BlockedOneTo{Int64, Vector{Int64}}, BlockedOneTo{Int64, Vector{Int64}}}}}:
 (2, 1)  (2, 1)  (2, 1)
 (1, 1)  (1, 1)  (1, 1)

julia> blocksizes(A)[2, 2]
(1, 1)
```
"""
blocksizes(A::AbstractArray) = BlockSizes(A)

axes(b::AbstractBlockedUnitRange) = (BlockedOneTo(blocklasts(b) .- (first(b)-oneunit(eltype(b)))),)
unsafe_indices(b::AbstractBlockedUnitRange) = axes(b)
# ::Integer works around case where blocklasts might return different type
last(b::AbstractBlockedUnitRange)::Integer = isempty(blocklasts(b)) ? first(b)-oneunit(eltype(b)) : last(blocklasts(b))

# view and indexing are identical for a unitrange
view(b::AbstractBlockedUnitRange, K::Block{1}) = b[K]

@propagate_inbounds function getindex(b::AbstractBlockedUnitRange, K::Block{1})
    k = Integer(K)
    bax = blockaxes(b,1)
    cs = blocklasts(b)
    @boundscheck K in bax || throw(BlockBoundsError(b, k))
    S = first(bax)
    K == S && return first(b):first(cs)
    return cs[k-1]+oneunit(eltype(b)):cs[k]
end

@propagate_inbounds function getindex(b::AbstractBlockedUnitRange, KR::BlockRange{1})
    cs = blocklasts(b)
    isempty(KR) && return _BlockedUnitRange(oneunit(eltype(b)),cs[1:0])
    K,J = first(KR),last(KR)
    k,j = Integer(K),Integer(J)
    bax = blockaxes(b,1)
    @boundscheck K in bax || throw(BlockBoundsError(b,K))
    @boundscheck J in bax || throw(BlockBoundsError(b,J))
    K == first(bax) && return _BlockedUnitRange(first(b),cs[k:j])
    _BlockedUnitRange(cs[k-1]+oneunit(eltype(b)),cs[k:j])
end

@propagate_inbounds function getindex(b::AbstractBlockedUnitRange, KR::BlockRange{1,Tuple{Base.OneTo{Int}}})
    cs = blocklasts(b)
    _getindex(b, blocklengths) = _BlockedUnitRange(first(b), blocklengths)
    _getindex(b::BlockedOneTo, blocklengths) = BlockedOneTo(blocklengths)
    isempty(KR) && return _getindex(b, cs[Base.OneTo(0)])
    J = last(KR)
    j = Integer(J)
    bax = blockaxes(b,1)
    @boundscheck J in bax || throw(BlockBoundsError(b,J))
    _getindex(b, cs[Base.OneTo(j)])
end

@propagate_inbounds getindex(b::AbstractBlockedUnitRange, KR::BlockSlice) = b[KR.block]

_searchsortedfirst(a::AbstractVector, k) = searchsortedfirst(a, k)
function _searchsortedfirst(a::Tuple, k)
    k ≤ first(a) && return 1
    1+_searchsortedfirst(tail(a), k)
end
_searchsortedfirst(a::Tuple{}, k) = 1

function findblock(b::AbstractBlockedUnitRange, k::Integer)
    @boundscheck k in b || throw(BoundsError(b,k))
    Block(_searchsortedfirst(blocklasts(b), k))
end

Base.dataids(b::AbstractBlockedUnitRange) = Base.dataids(blocklasts(b))


###
# BlockedUnitRange interface
###
Base.checkindex(::Type{Bool}, b::BlockRange, K::Int) = checkindex(Bool, Int.(b), K)
Base.checkindex(::Type{Bool}, b::AbstractUnitRange{Int}, K::Block{1}) = checkindex(Bool, blockaxes(b,1), Int(K))

function Base.checkindex(::Type{Bool}, axis::AbstractBlockedUnitRange, ind::BlockIndexRange{1})
    checkindex(Bool, axis, first(ind)) && checkindex(Bool, axis, last(ind))
end
function Base.checkindex(::Type{Bool}, axis::AbstractBlockedUnitRange, ind::BlockIndex{1})
    checkindex(Bool, axis, block(ind)) && checkbounds(Bool, axis[block(ind)], blockindex(ind))
end

@propagate_inbounds function getindex(b::AbstractUnitRange{Int}, K::Block{1})
    @boundscheck K == Block(1) || throw(BlockBoundsError(b, K))
    b
end

@propagate_inbounds function getindex(b::AbstractUnitRange{Int}, K::BlockRange)
    @boundscheck K == Block.(1:1) || throw(BlockBoundsError(b, K))
    b
end

blockaxes(b::AbstractUnitRange{Int}) = (Block.(Base.OneTo(1)),)

function findblock(b::AbstractUnitRange{Int}, k::Integer)
    @boundscheck k in axes(b,1) || throw(BoundsError(b,k))
    Block(1)
end

"""
    blockfirsts(a::AbstractUnitRange{<:Integer})

Return the first index of each block of `a`.

# Examples
```jldoctest
julia> b = blockedrange([1,2,3])
3-blocked 6-element BlockedOneTo{Int64, Vector{Int64}}:
 1
 ─
 2
 3
 ─
 4
 5
 6

julia> blockfirsts(b)
3-element Vector{Int64}:
 1
 2
 4
```
"""
blockfirsts(a::AbstractUnitRange{<:Integer}) = Ones{eltype(a)}(1)
"""
    blocklasts(a::AbstractUnitRange{<:Integer})

Return the last index of each block of `a`.

# Examples
```jldoctest
julia> b = blockedrange([1,2,3])
3-blocked 6-element BlockedOneTo{Int64, Vector{Int64}}:
 1
 ─
 2
 3
 ─
 4
 5
 6

julia> blocklasts(b)
3-element Vector{Int64}:
 1
 3
 6
```
"""
blocklasts(a::AbstractUnitRange{<:Integer}) = Fill(eltype(a)(length(a)),1)
"""
    blocklengths(a::AbstractUnitRange{<:Integer})

Return the length of each block of `a`.

# Examples
```jldoctest
julia> b = blockedrange([1,2,3])
3-blocked 6-element BlockedOneTo{Int64, Vector{Int64}}:
 1
 ─
 2
 3
 ─
 4
 5
 6

julia> blocklengths(b)
3-element Vector{Int64}:
 1
 2
 3
```
"""
blocklengths(a::AbstractUnitRange{<:Integer}) = blocklasts(a) .- blockfirsts(a) .+ oneunit(eltype(a))

Base.summary(io::IO, a::AbstractBlockedUnitRange) =  _block_summary(io, a)


###
# Slice{<:BlockedOneTo}
###

Base.axes(S::Base.Slice{<:BlockedOneTo}) = (S.indices,)
Base.unsafe_indices(S::Base.Slice{<:BlockedOneTo}) = (S.indices,)
blockaxes(S::Base.Slice) = blockaxes(S.indices)
@propagate_inbounds getindex(S::Base.Slice, b::Block{1}) = S.indices[b]
@propagate_inbounds getindex(S::Base.Slice, b::BlockRange{1}) = S.indices[b]


# This supports broadcasting with infinite block arrays
_broadcaststyle(_) = Broadcast.DefaultArrayStyle{1}()
Base.BroadcastStyle(::Type{<:AbstractBlockedUnitRange{<:Any,R}}) where R = _broadcaststyle(Base.BroadcastStyle(R))

###
# Special Fill/Range cases
#
# We want to use lazy types when possible
###

const OneToCumsum = RangeCumsum{Int,Base.OneTo{Int}}
sortedunion(a::OneToCumsum, ::OneToCumsum) = a
function sortedunion(a::RangeCumsum{<:Any,<:AbstractRange}, b::RangeCumsum{<:Any,<:AbstractRange})
    @assert a == b
    a
end

_blocklengths2blocklasts(blocks::AbstractRange) = RangeCumsum(blocks)
function blockfirsts(a::AbstractBlockedUnitRange{<:Any,Base.OneTo{Int}})
    first(a) == 1 || error("Offset axes not supported")
    Base.OneTo{eltype(a)}(length(blocklasts(a)))
end
function blocklengths(a::AbstractBlockedUnitRange{<:Any,Base.OneTo{Int}})
    first(a) == 1 || error("Offset axes not supported")
    Ones{eltype(a)}(length(blocklasts(a)))
end
function blockfirsts(a::AbstractBlockedUnitRange{<:Any,<:AbstractRange})
    st = step(blocklasts(a))
    first(a) == 1 || error("Offset axes not supported")
    @assert first(blocklasts(a))-first(a)+oneunit(eltype(a)) == st
    range(oneunit(eltype(a)); step=st, length=eltype(a)(length(blocklasts(a))))
end
function blocklengths(a::AbstractBlockedUnitRange{<:Any,<:AbstractRange})
    st = step(blocklasts(a))
    first(a) == 1 || error("Offset axes not supported")
    @assert first(blocklasts(a))-first(a)+oneunit(eltype(a)) == st
    Fill(st,length(blocklasts(a)))
end


# TODO: Remove

function _last end
function _length end
