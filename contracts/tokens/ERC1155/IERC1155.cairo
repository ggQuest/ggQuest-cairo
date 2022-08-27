%lang starknet

@contract_interface
namespace IERC1155:
    func balanceOf(owner : felt) -> (balance : felt):
    end
end