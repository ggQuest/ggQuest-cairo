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
from contracts.interfaces.IggProfiles import IggProfiles

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

struct PlayersStruct:
    member len_players : felt
    member players_arr : felt*
end

struct AdditionalRewardsStruct: 
    member len_additional_rewards : felt
    member additional_rewards_arr : Reward*
end


@storage_var
func metadata_URL() -> (res : felt):
end

@storage_var
func reputation_reward() -> (res : felt):
end

@storage_var
func is_active() -> (res : felt):
end

@storage_var
func profiles()->(res : felt):
end


@storage_var
func players() -> (res : felt*):
end

@storage_var
func completed_by(address:felt)->(res : felt):
end

@storage_var
func operators(address:felt) -> (res : felt):
end

@storage_var
func additional_rewards()-> (res : AdditionalRewardsStruct):
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
    profiles.write(gg_profiles_contract)
    let (caller) = get_caller_adddress()
    operators.write(caller, true)
    return ()
end

@view
func get_additional_rewards{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (rewards : AdditionalRewardsStruct):
    let (rewards) = additional_rewards.read()
    return (rewards)
end

@view
func get_players{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (players : PlayersStruct):
    let (players) = players.read()
    return (players)
end

@view
func get_quest_URI()-> (res : felt):
    let (metadata_URL) = metadata_URL.read()
    return (res=metadata_URL)
end


@external
func add_operator(operator:felt):
    operators.write(operator, true)
    operator_added.emit(operator)

    return ()
end

@external
func remove_operator(operator:felt):
    operators.write(operator, false)
    operator_removed(operator)

    return ()
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
        else:
            let (balance : Uint256) = IERC1155.balanceOf(contract_address=reward.reward_contract, contract_address, reward.id)
            let (local product : Uint256) = reward.tokenAmount * reward.amount
            with_attr error_message("ggQuests contract doesn't own enough tokens"):
                let (enough) = uint256_le(product, balance)
                assert_not_zero(enough)
            end
        end
    end

    return ()

end

@view
func get_rewards()->(additional_rewards: Reward*, len_rewards : felt):

end

@external
func send_reward(player : felt):   
    alloc_locals
    let (completed_by) = completed_by.read(address=player)
    with_attr error_message("Quest already completed by this player"):
        assert completed_by = true
    end
    let start = Uint256(0,0)
    let (struct_rewards) = get_additional_rewards()
    let (stop) = struct_rewards.len_additional_rewards
    let (had_at_least_one_reward) = _send_loop_reward{player=player, stop=stop}(start)
    with_attr error_message("All rewards have already been distributed"):
        assert had_at_least_one_reward = TRUE
    end
    
    let (players_struct) = get_players()
    # push player in players array
    _push_to_players(players_struct, player)
    completed_by.write(player, true)

    let (profiles) = profiles.read()
    let (reputation_reward) = reputation_reward.read()
    IggProfiles.increase_reputation(contract_address=profiles, player, reputation_reward)

    reward_sent.emit(player, reward)
end

@external
func increase_reward_amount(amount : Uint256, reward : Reward):
    let start = Uint256(0,0)
    let (struct_rewards) = get_additional_rewards()
    let (stop) = struct_rewards.len_additional_rewards    
    let (exists) = _increase_reward_token{stop=stop, amount=amount, reward=reward}(start)
    with_attr error_message("Given reward (token address) doesn't exist for this quest"):
        assert exists = TRUE
    end
    return ()
end

@external
func update_reputation_reward(new_value : felt):
    reputation_reward.write(new_value)
    reputation_reward_updated.emit(new_value)
    return ()
end

@external
func activate_quest():
    is_active.write(TRUE)
    quest_activated.emit()
    return ()
end

@external
func deactivate_quest(withdrawal_address : felt):
    is_active.write(FALSE)
    # transfer all tokens
    let start = Uint256(0,0)
    let (struct_rewards) = get_additional_rewards()
    let (stop) = struct_rewards.len_additional_rewards
    _transfer_tokens{stop=stop, withdraw_address=withdraw_address}(start)
    quest_deactivated.emit()
    return ()
end



# private
func withdraw_reward(reward_id : felt, withdrawal_address : felt);
    let (additional_reward_struct) = additional_rewards.read()
    let rewards_arr = additional_reward_struct.additional_rewards_arr
    let reward_type = rewards_arr[reward_id].reward_type
    let reward_contract = rewards_arr[reward_id].reward_contract

    let (contract_address) = get_contract_address

    if reward_type == RewardType.ERC20 :
        let (balance : Uint256) = IERC20.balanceOf(contract_address=reward_contract, account=contract_address)
        let (success) = IERC20.transfer(contract_address=reward_contract, balance)
        with_attr error_message("transfer ERC20 failed"):
            assert_not_zero(success)
        end
    else:
        
        let (amount) = rewards_arr[reward_id].id

        if reward_type ==  RewardType.ERC721 :
            let (success) = IERC20.transferFrom(
                contract_address=reward_contract, 
                contract_address, 
                withdrawal_address,
                amount
            )
            with_attr error_message("transfer ERC721 failed"):
                assert_not_zero(success)
            end

        else:
            let (balance : Uint256) = IERC1155.balanceOf(
                contract_address=reward_contract,
                contract_address,
                amount
            )
            let (success) = IERC1155.safeTransferFrom(
                contract_address=reward_contract,
                contract_address,
                withdrawal_address,
                amount,
                balance,
                ""
            )
            with_attr error_message("transfer ERC1155 failed"):
                assert_not_zero(success)
            end
    return ()
end

# internals

func _reward_hash(reward : Reward) -> (bytes : felt):
    #todo
end

func _send_loop_reward{
    player : felt,
    stop : felt,
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}(start : felt) -> (had_at_least_one_reward : felt):
    alloc_locals


end

func _push_to_players{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}(struct : PlayersStruct, player : felt):

    return ()
end

func _push_to_rewards{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}(struct : AdditionalRewardsStruct, reward : Reward):
    

    return ()
end