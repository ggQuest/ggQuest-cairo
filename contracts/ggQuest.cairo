%lang starknet

from starware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

# enum-like
struct RewardType:
    member ERC20 : felt
    member ERC721 : felt
    member ERC1155 : felt
end

struct Reward:
    member reward_type: RewardType
    member reward_contract: felt
    member token_amount: felt
    member amount: felt
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

func _verifyTokenOwnershipFor(reward: Reward):
    if reward.reward_type == RewardType.ERC20:
        with_attr error_message("):

        end

end