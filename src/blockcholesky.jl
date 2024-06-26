
##########################################
# Cholesky Factorization on BlockMatrices#
##########################################


function _diag_chol!(A::AbstractArray{T}, i::Int, uplo) where T<:Real
    Pii = view(A,Block(i,i))
    for k = Int(first(blockcolsupport(A,Block(i)))):i-1
        muladd!(-one(T), view(A,Block(k,i))', view(A,Block(k,i)), one(T), Pii)
    end
    return LAPACK.potrf!('U', Pii)
end


function _nondiag_chol!(A::AbstractArray{T}, i::Int, n::Int, ::Type{UpperTriangular}) where T<:Real
    for j = i+1:Int(last(blockrowsupport(A,Block(i))))
        Pij = view(A,Block(i,j))
        for k = Int(first(blockcolsupport(A,Block(j)))):i-1
            muladd!(-one(T), view(A,Block(k,i))', view(A,Block(k,j)), one(T), Pij)
        end
        # use ArrayLayouts.ldiv! to take advantage of layout
        ArrayLayouts.ldiv!(transpose(UpperTriangular(view(A,Block(i,i)))), Pij)
    end
end

function _nondiag_chol!(A::AbstractArray{T}, i::Int, n::Int, ::Type{LowerTriangular}) where T<:Real
    for j = i+1:Int(last(blockrowsupport(A,Block(i))))
        Pij = view(A,Block(i,j))
        for k = Int(first(blockcolsupport(A,Block(j)))):i-1
            muladd!(-one(T), view(A,Block(k,i))', view(A,Block(k,j)), one(T), Pij)
        end
        ArrayLayouts.ldiv!(UpperTriangular(view(A,Block(i,i)))', Pij)
    end
end

function _block_chol!(A::AbstractArray{T}, ::Type{UpperTriangular}) where T<:Real
    n = blocksize(A)[1]

    @inbounds begin
        for i = 1:n
            _, info = _diag_chol!(A, i, UpperTriangular)

            if !iszero(info)
                @assert info > 0
                if i == 1
                    return UpperTriangular(A), info
                end
                info += sum(size(A[Block(l,l)])[1] for l=1:i-1) 
                return UpperTriangular(A), info
            end

            _nondiag_chol!(A, i, n, UpperTriangular)
        end
    end

    return UpperTriangular(A), 0
end

function _block_chol!(A::AbstractArray{T}, ::Type{LowerTriangular}) where T<:Real
    n = blocksize(A)[1]
    A = copy(transpose(A))

    @inbounds begin
        for i = 1:n
            _, info = _diag_chol!(A, i, LowerTriangular)

            if !iszero(info)
                @assert info > 0
                if i == 1
                    return LowerTriangular(copy(transpose(A))), info
                end
                info += sum(size(A[Block(l,l)])[1] for l=1:i-1) 
                return LowerTriangular(A), info
            end
    
            _nondiag_chol!(A, i, n, LowerTriangular)
        end
    end

    return LowerTriangular(transpose(A)), 0
end

function ArrayLayouts._cholesky!(layout, ::NTuple{2,AbstractBlockedUnitRange}, A::RealHermSymComplexHerm, ::ArrayLayouts.CNoPivot; check::Bool = true)
    C, info = _block_chol!(A.data, A.uplo == 'U' ? UpperTriangular : LowerTriangular)
    check && LinearAlgebra.checkpositivedefinite(info)
    return Cholesky(C.data, A.uplo, info)
end

