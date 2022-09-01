%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address
)

from starkware.cairo.common.uint256 import (
    Uint256, 
    uint256_add,
    uint256_sub,
    uint256_le,
    uint256_lt,
    uint256_check,
    assert_not_zero as uint_256_assert_not_zero
)

from starkware.cairo.common.math import (
    assert_not_zero,
    assert_nn_le,
    assert_in_range,
    assert_not_equal,
    assert_nn,
    assert_le,
    assert_lt
)

from contracts.tokens.ERC20.IERC20 import IERC20
from contracts.tokens.ERC721.IERC721 import IERC721
from contracts.tokens.ERC1155.IERC1155 import IERC1155

from contracts.interfaces.IggProfiles import IggProfiles


############
#  STRUCTS 
############

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

############
#  STORAGE 
############

@storage_var
func Players(index : felt) -> (player : felt):
end 

@storage_var
func Players_Len() -> (len : felt):
end

@storage_var
func Additional_Rewards(index : felt)->(additional_reward : Reward):
end

@storage_var
func Additional_Rewards_Len() -> (len : felt):
end

@storage_var
func Metadata_URL() -> (res : felt):
end

@storage_var
func Reputation_Reward() -> (res : felt):
end

@storage_var
func Is_Active() -> (res : felt):
end

@storage_var
func Profiles()->(res : felt):
end

@storage_var
func Completed_By(address : felt)->(res : felt):
end

@storage_var
func Operators(address : felt) -> (res : felt):
end

############
#  EVENT 
############

@event
func OperatorAdded(operator : felt):
end

@event
func OperatorRemoved(operator : felt):
end

@event
func reward_added(reward : Reward):
end

@event 
func RewardSent(player : felt):
end

@event
func ReputationRewardUpdated(res : felt):
end

@event
func QuestActivated():
end

@event
func QuestDeactivated(withdraw_address : felt):
end

############
#  CONSTRUCTOR 
############

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    gg_profiles_contract : felt, reputation_reward : felt, metadata_URL : felt
):  
    alloc_locals
    Metadata_URL.write(metadata_URL)
    Reputation_Reward.write(reputation_reward)
    Profiles.write(gg_profiles_contract)
    let (caller) = get_caller_address()
    Operators.write(caller, 1)

    return ()
end

############
#  VIEW 
############

@view
func get_additional_rewards{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (rewards_len : felt , rewards : Reward*):
    alloc_locals
    let (rewards_len) = Additional_Rewards_Len.read()
    let (local rewards_array : Reward*) = alloc()
    let (local start) = 0
    let stop = rewards_len
    # to add a check if its zero
    
    get_additional_rewards_loop{rewards_array=rewards_array, stop=stop}(start)
    return (rewards_len=rewards_len, rewards=rewards_array)
end

@view
func get_players{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (players_len : felt, players : felt*):
    alloc_locals
    let (players_len) = Players_Len.read()
    let (local players_array : felt*) = alloc()
    let (local start) = 0
    let stop = players_len
    # to add a check if its zero

    get_players_loop{players_array=players_array, stop=stop}(start)
    return (players_len=players_len, players=players_array)
end


@view
func get_quest_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):
    let (metadata_URL) = Metadata_URL.read()
    return (res=metadata_URL)
end

@view
func is_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
) -> (res : felt):
    let (res) = Operators.read(operator)
    return (res)
end

@view
func get_active{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (res : felt):
    let (res) = Is_Active.read()
    return (res)
end

@view
func is_completed_by{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
) -> (res : felt):
    let (completed_by) = Completed_By.read(address)
    return (res=completed_by)
end

@view
func get_ggProfile_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):
    let (contract) = Profiles.read()
    return (res=contract)
end

@view
func get_reputation_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):
    let (reputation_reward) = Reputation_Reward.read()
    return (res=reputation_reward)
end

############
#  EXTERNAL 
############

@external
func add_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):
    assert_only_operator()
    Operators.write(operator, 1)
    OperatorAdded.emit(operator)

    return ()
end

@external
func remove_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):
    assert_only_operator()
    Operators.write(operator, 0)
    OperatorRemoved(operator)

    return ()
end

@external
func add_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reward : Reward
) -> (res : felt):
    alloc_locals

    assert_only_operator()

    let (active) = Is_Active.read()
    with_attr error_message("Rewards cannot be added after quest activation"):
        assert active = 0
    end

    # Verify if rewards are unique (not twice the same ERC721 for example)
    local start = 0
    let (rewards_len) = Additional_Rewards_Len.read()
    let stop = rewards_len

    # loop to check if rewards are unique
    verify_uniqueness_of_rewards_loop{stop=stop, reward=reward}(start)

    _verifyTokenOwnershipFor(reward)

    Additional_Rewards.write(rewards_len, reward)
    Additional_Rewards_Len.write(rewards_len + 1)

    reward_added.emit(reward)

    return (res=rewards_len - 1)
end

@external
func send_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    player : felt
):   
    alloc_locals
    assert_only_operator()

    let (completed_by) = Completed_By.read(address=player)
    with_attr error_message("Quest already completed by this player"):
        assert completed_by = 1
    end
    local start = 0
    let (rewards_len) = Additional_Rewards_Len.read()
    let stop = rewards_len
    local had_at_least_one_reward = 0
    send_reward_loop{
        player=player, 
        stop=stop, 
        had_at_least_one_reward=had_at_least_one_reward
    }(start)
    with_attr error_message("All rewards have already been distributed"):
        assert had_at_least_one_reward = 1
    end
    
    let (players_len) = Players_Len.read()

    # push player in players array
    Players.write(players_len, player)
    Players_Len.write(players_len + 1)
    Completed_By.write(player, 1)

    let (profiles) = Profiles.read()
    let (reputation_reward) = Reputation_Reward.read()
    IggProfiles.increase_reputation(contract_address=profiles, player, reputation_reward)

    #todo 
    #let (local reward : Reward) = Reward(RewardType.ERC20, 0, Uint256(0,0), Uint256(0,0), 0)
    RewardSent.emit(player)
end

@external
func increase_reward_amount{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : Uint256, reward : Reward
):
    alloc_locals
    local start = 0
    let (rewards_len) = Additional_Rewards_Len.read()
    let stop = rewards_len
    local exists = 0
    increase_reward_token_loop{stop=stop, amount=amount, reward=reward, exists=exists}(start)
    with_attr error_message("Given reward (token address) doesn't exist for this quest"):
        assert exists = 1
    end
    return ()
end

@external
func update_reputation_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_value : felt
):
    assert_only_operator()

    Reputation_Reward.write(new_value)
    R.emit(new_value)
    return ()
end

@external
func activate_quest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
):
    assert_only_operator()

    Is_Active.write(1)
    Q.emit()
    return ()
end

@external
func deactivate_quest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    withdrawal_address : felt
):
    alloc_locals
    assert_only_operator()

    Is_Active.write(0)
    # transfer all tokens
    local start = 0
    let (rewards_len) = Additional_Rewards_Len.read()
    let stop = rewards_len
    deactivate_loop{stop=stop, withdrawal_address=withdrawal_address}(start)
    Q.emit()
    return ()
end

############
# MODIFIER
############
func assert_only_operator{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}():
    let (caller) = get_caller_address()
    with_attr error_message("caller is the zero address"):
        assert_not_zero(caller)
    end
    let (is_op) = Operators.read(caller)
    with_attr error_message("only operators can call this function"):
        assert is_op = 1
    end
end


############
#  PRIVATE 
############

# private functions

func _verifyTokenOwnershipFor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reward : Reward
):
    alloc_locals
    let (contract_address) = get_contract_address()

    if reward.reward_type == RewardType.ERC20:
        let (balance : Uint256) = IERC20.balanceOf(contract_address=reward.reward_contract, account=contract_address)
        let (local product : Uint256) = reward.tokenAmount * reward.amount
        with_attr error_message("ggQuest contract doesn't own enough tokens"):
            let (enough) = uint256_le(product, balance)
            uint_256_assert_not_zero(enough)
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
                uint_256_assert_not_zero(enough)
            end
        end
    end

    return ()

end


func withdraw_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reward_id : felt, withdrawal_address : felt
):
    let (additional_reward_struct) = Additional_Rewards.read()
    let rewards_arr = additional_reward_struct.additional_rewards_arr
    let reward_type = rewards_arr[reward_id].reward_type
    let reward_contract = rewards_arr[reward_id].reward_contract

    let (contract_address) = get_contract_address()

    if reward_type == RewardType.ERC20 :
        let (balance : Uint256) = IERC20.balanceOf(contract_address=reward_contract, account=contract_address)
        let (success) = IERC20.transfer(contract_address=reward_contract, balance)
        with_attr error_message("transfer ERC20 failed"):
            uint_256_assert_not_zero(success)
        end
    else:
        
        let amount = rewards_arr[reward_id].id

        if reward_type ==  RewardType.ERC721 :
            let (success) = IERC721.transferFrom(
                contract_address=reward_contract, 
                contract_address, 
                withdrawal_address,
                amount
            )
            with_attr error_message("transfer ERC721 failed"):
                uint_256_assert_not_zero(success)
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
                uint_256_assert_not_zero(success)
            end
        end
    end

    return ()
end

############
#  INTERNAL 
############

func _reward_hash{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reward : Reward
) -> (bytes : felt):
    #todo
end

func deactivate_loop{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    stop : felt, 
    withdrawal_address : felt
}(start : felt):
    if start == stop:
        return ()
    end

    _withdraw_reward(start, withdrawal_address)

    deactivate_loop(start + 1)
    return ()
end

#todo
func verify_uniqueness_of_rewards_loop{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    stop : felt,
    reward : Reward,
}(start : felt):
     if start == stop:
        return ()
    end
    
    let (additional_reward) = Additional_Rewards.read(start)
    let (rhAR) = _reward_hash(additional_reward)
    let (rhR) = _reward_hash(reward)

    with_attr error_message("Token contract already used in another reward of the quest"):
        assert_not_equal(rhAR, rhR)
    end

    verify_uniqueness_of_rewards_loop(start + 1)
    return ()
end

func increase_reward_token_loop{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    stop : felt, 
    amount : felt, 
    reward : Reward,
    exists : felt
}(start : felt):
    alloc_locals

    if start == stop:
        return ()
    end

    let (additional_reward) = Additional_Rewards.read(start)
    let (rhAR) = _reward_hash(additional_reward)
    let (rhR) = _reward_hash(reward)
    if rhAR == rhR :
        tempvar exists = 1
        let (local reward_test : Reward) = Additional_Rewards.read(start)
        let (players_len) = Players_Len.read()
        let (local amount_test) = reward_test.amount + amount - players_len
        
        _verifyTokenOwnershipFor(reward_test)
        local new_reward : Reward
        assert new_reward.reward_type = additional_rewards.reward_type
        assert new_reward.reward_contract = additional_rewards.reward_contract
        assert new_reward.token_amount = additional_rewards.token_amount
        assert new_reward.amount = additional_rewards.amount + amount
        assert new_reward.id = additional_rewards.id
           
        Additional_Rewards.write(start, new_reward)       
    end
    increase_reward_token_loop(start + 1)
end

func _transfer_tokens{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    stop : felt,
    withdraw_address : felt
}(start : felt):
end

func send_reward_loop{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    player : felt,
    stop : felt,
    had_at_least_one_reward : felt
}(start : felt):
    alloc_locals
    if start == stop:
        return ()
    end

    let (reward : Reward) = Additional_Rewards.read(start)
    let (players_len : felt) = Players_Len.read()
    let (enough_rewards) = uint256_le(players_len, reward.amount)
    
    if enough_rewards == 1 :
        tempvar had_at_least_one_reward = 1
        let token_address = reward.reward_contract

        if reward.reward_type == RewardType.ERC20:
            IERC20.transfer(contract_address=token_address, player, reward.token_amount)
        else:
            if reward.reward_type == RewardType.ERC721:
            let (contract_add) = get_contract_address()
                IERC721.safeTransferFrom(contract_address=token_address, contract_add, player, reward_id)
            else :
                IERC1155.safeTransferFrom(contract_address=token_address, contract_add, player, reward_id, reward.token_amount, 0)
            end
        end
    end
    send_reward_loop(start + 1)

    return ()
end

func get_additional_rewards_loop{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    rewards_array : Reward*,
    stop : felt,
}(start : felt):
    if start == stop:
        return ()
    end

    let (reward : Reward) = Additional_Rewards.read(start)
    assert [rewards_array + start] = reward
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    get_additional_rewards_loop(start + 1)
end

func get_players_loop{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    players_array : Reward*,
    stop : felt,
}(start : felt):
    if start == stop:
        return ()
    end
    let (player : felt) = Players.read(start)
    assert [players_array + start] = player
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    get_players_loop(start + 1)
end
