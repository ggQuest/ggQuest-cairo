%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC721Metadata:
    func name() -> (name : felt):
    end

    func symbol() -> (symbol : felt):
    end

    func tokenURI(token_id : Uint256) -> (tokenURI : felt):
    end
end