%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC1155:
    func balanceOf(owner : felt) -> (balance : Uint256):
    end

    func safeTransferFrom(
        _from : felt, to : felt, token_id : Uint256, amount : Uint256
    ):
    end

end