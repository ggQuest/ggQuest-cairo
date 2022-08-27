%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
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

from contracts.tokens.ERC20.IERC20 import IERC20
from contracts.tokens.ERC721.IERC721 import IERC721

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



@storage_var
func players(index : felt) -> (player : felt):
end 

@storage_var
func players_len() -> (len : felt):
end

@storage_var
func additional_rewards(index : felt)->(additional_reward : Reward):
end

@storage_var
func additional_rewards_len() -> (len : felt):
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
func completed_by(address : felt)->(res : felt):
end

@storage_var
func operators(address : felt) -> (res : felt):
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
func reward_sent(player : felt, reward : Reward):
end

@event
func reputation_reward_updated(res : felt):
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
    alloc_locals
    metadata_URL.write(metadata_URL)
    reputation_reward.write(reputation_reward)
    profiles.write(gg_profiles_contract)
    let (caller) = get_caller_adddress()
    operators.write(caller, true)

    return ()
end

@view
func get_additional_rewards{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (rewards : Reward*, rewards_len : felt):
    alloc_locals
    let (rewards_len) = additional_rewards_len.read()
    let (local rewards_array : Reward*) = alloc()
    let start = Uint256(0,0)
    let stop = rewards_len
    # to add a check if its zero

    _get_additional_rewards{rewards_array=rewards_array, stop=stop}(start)
    return (rewards=rewards_array, rewards_len=rewards_len)
end

@view
func get_players{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (players : felt*, players_len : felt):
    alloc_locals
    let (players_len) = players_len.read()
    let (local players_array : felt*) = alloc()
    let start = Uint256(0,0)
    let stop = players_len
    # to add a check if its zero

    _get_players{players_array=players_array, stop=stop}(start)
    return (players=players_array, players_len=players_len)
end


@view
func get_quest_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):
    let (metadata_URL) = metadata_URL.read()
    return (res=metadata_URL)
end

@view
func is_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
) -> (res : felt):
    let (res) = operators.read(operator)
    return (res)
end

@view
func get_active{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (res : felt):
    let (res) = is_active.read()
    return (res)
end

@view
func is_completed_by{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
) -> (res : felt):
    let (completed_by) = completed_by.read(address)
    return (res=completed_by)
end

@view
func get_ggProfile_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):
    let (contract) = profiles.read()
    return (res=contract)
end

@view
func get_reputation_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):
    let (reputation_reward) = reputation_reward.read()
    return (res=reputation_reward)
end

@external
func add_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):
    operators.write(operator, true)
    operator_added.emit(operator)

    return ()
end

@external
func remove_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):
    operators.write(operator, false)
    operator_removed(operator)

    return ()
end

@external
func add_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reward : Reward
) -> (res : Uint256):
    let (active) = is_active.read()
    with_attr error_message("Rewards cannot be added after quest activation"):
        assert active = FALSE
    end

    # Verify if rewards are unique (not twice the same ERC721 for example)
    let start = Uint256(0,0)
    let (rewards_len) = additional_rewards_len.read()
    let stop = rewards_len
    _verifyUniquenessOfRewards{stop=stop, reward=reward}(start)

    verifyTokenOwnershipFor(reward)
    # todo
    # loop to check if rewards are unique

    additional_rewards.write(rewards_len, reward)
    additional_rewards_len.write(rewards_len + 1)

    reward_added.emit(reward)
    #let one = Uint256(1,1)
    #let (res : Uint256) = uint256_sub(rewards_len, one)

    return (res=rewards_len - 1)

end

@external
func send_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    player : felt
):   
    alloc_locals
    let (completed_by) = completed_by.read(address=player)
    with_attr error_message("Quest already completed by this player"):
        assert completed_by = TRUE
    end
    let start = Uint256(0,0)
    let (rewards_len) = additional_rewards_len.read()
    let stop = rewards_len
    let (had_at_least_one_reward) = _send_loop_reward{player=player, stop=stop}(start)
    with_attr error_message("All rewards have already been distributed"):
        assert had_at_least_one_reward = TRUE
    end
    
    let (players_len) = players_len.read()

    # push player in players array
    players.write(players_len, player)
    players_len.write(players_len + 1)
    completed_by.write(player, true)

    let (profiles) = profiles.read()
    let (reputation_reward) = reputation_reward.read()
    IggProfiles.increase_reputation(contract_address=profiles, player, reputation_reward)

    reward_sent.emit(player, reward)
end

@external
func increase_reward_amount{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : Uint256, reward : Reward
):
    let start = Uint256(0,0)
    let (rewards_len) = additional_rewards_len.read()
    let stop = rewards_len
    let (exists) = _increase_reward_token{stop=stop, amount=amount, reward=reward}(start)
    with_attr error_message("Given reward (token address) doesn't exist for this quest"):
        assert exists = TRUE
    end
    return ()
end

@external
func update_reputation_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_value : felt
):
    reputation_reward.write(new_value)
    reputation_reward_updated.emit(new_value)
    return ()
end

@external
func activate_quest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
):
    is_active.write(TRUE)
    quest_activated.emit()
    return ()
end

@external
func deactivate_quest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    withdrawal_address : felt
):
    is_active.write(FALSE)
    # transfer all tokens
    let start = Uint256(0,0)
    let (rewards_len) = additional_rewards_len.read()
    let stop = rewards_len
    _transfer_tokens{stop=stop, withdraw_address=withdraw_address}(start)
    quest_deactivated.emit()
    return ()
end


# private functions

func verifyTokenOwnershipFor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reward: Reward
):
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



func withdraw_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reward_id : felt, withdrawal_address : felt
):
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
            let (success) = IERC721.transferFrom(
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
                0
            )
            with_attr error_message("transfer ERC1155 failed"):
                assert_not_zero(success)
            end
        end
    end

    return ()
end

# internals

func _reward_hash{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reward : Reward
) -> (bytes : felt):
    #todo
end

#todo
func _verifyUniquenessOfRewards{
    stop : felt,
    reward : Reward,
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}():

    return ()
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

func _get_additional_rewards{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    rewards_array : Reward*,
    stop : felt,
}(start : Uint256):

end

func _get_players{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    players_array : Reward*,
    stop : felt,
}(start : Uint256):

end
