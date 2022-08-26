%lang starknet

from starware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (
    get_contract_address,
)

from starkware.cairo.common.uint256 import (
    Uint256, 
    uint256_add,
    uint256_sub,
    uint256_le,
    uint256_lt,
    uint256_check,
)

from contracts.token.IERC20 import IERC20

# enum-like
struct RewardType:
    member ERC20 : felt
    member ERC721 : felt
    member ERC1155 : felt
end

struct Reward:
    member reward_type: RewardType
    member reward_contract: felt
    member token_amount: Uint256
    member amount: Uint256
    member id: felt
end

@storage_var
func metadata_URL() -> (res: felt):
end

@storage_var
func reputation_reward() -> (res: felt):
end

@storage_var
func is_active() -> (res: felt):
end

@storage_var
func profiles()->(res: ggProfile):
end

@storage_var
func players() -> (res:felt*):
end

@storage_var
func completed_by(address:felt)->(res: felt):
end

@storage_var
func operators(address:felt) -> (res:felt):
end

@storage_var
func additional_rewards()-> (res : Reward*):
end

@event
func operator_added(operator : felt):
end

@event
func operator_removed(operator : felt):
end

@event
func reward_added(reward : Reward):
end

@event 
func reward_sent(player : felt, reward: Reward):
end

@event
func reputation_reward_updated(res:felt):
end

@event
func quest_activated():
end

@event
func quest_deactivated(withdraw_address : felt):
end



@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
    gg_profiles_contract : felt, reputation_reward : felt, metadata_URL : felt
):
    metadata_URL.write(metadata_URL)
    reputation_reward.write(reputation_reward)
    let (gg_profile) = ggProfiles
    profiles.write()
    let (caller) = get_caller_adddress()
    operators.write(caller, true)
end



@external
func add_operator(operator:felt):
    operators.write(operator, true)
    operator_added.emit(operator)
end

@external
func remove_operator(operator:felt):
    operators.write(operator, false)
    operator_removed(operator)

end

@view
func is_operator(operator:felt) -> (res:felt):
    let (res) = operators.read(operator)
    return (res)
end

@external
func add_reward(reward : Reward) -> (res:felt):
    let (active) = is_active.read()
    with_attr error_message("Rewards cannot be added after quest activation"):
        assert active = false
    end

    _verifyTokenOwnershipFor(reward)
    # todo
    # loop to check if rewards are unique

    reward_added.emit(reward)

    let (res) = # todo

    return (res)

end

#should be provate view
func _verifyTokenOwnershipFor(reward: Reward):
    alloc_locals
    let (contract_address) = get_contract_address()

    if reward.reward_type == RewardType.ERC20:
        let (balance : Uint256) = IERC20.balanceOf(contract_address=reward.reward_contract, account=contract_address)
        let (local product : Uint256) = reward.tokenAmount * reward.amount
        with_attr error_message("ggQuest contract doesn't own enough tokens"):
            let (enough) = uint256_le(product, balance)
            assert_not_zero(enough)
        end
    else: 
        if reward.reward_type == RewardType.ERC721:
            let (owner) = IERC721.ownerOf(contract_address=reward.reward_contract, reward.id)
            with_attr error_message("ggQuests contract doesn't own this ERC721 token"):
                assert owner = contract_address
            end

            with_attr error_message("tokenAmount and amount should be 1 as ERC721 is unique"):
                assert reward.tokenAmount = 1
            end

            with_attr error_message("tokenAmount and amount should be 1 as ERC721 is unique"):
                assert reward.amount = 1
            end
        end
        else:
            let (balance : Uint256) = IERC1155.balanceOf(contract_address=reward.reward_contract, contract_address, reward.id)
            let (local product : Uint256) = reward.tokenAmount * reward.amount
            with_attr error_message("ggQuests contract doesn't own enough tokens"):
                let (enough) = uint256_le(product, balance)
                assert_not_zero(enough)
            end

        end

    end
    


end