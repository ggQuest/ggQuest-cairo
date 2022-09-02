%lang starknet

from starkware.cairo.common.cairo_builtins import (
    HashBuiltin, BitwiseBuiltin
)
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address
)
from starkware.cairo.common.bool import TRUE, FALSE

from starkware.cairo.common.cairo_keccak.keccak import keccak_felts, finalize_keccak

from starkware.cairo.common.math import (
    assert_not_equal,
    assert_lt_felt
)
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_sub,
    uint256_le,
    uint256_lt,
    uint256_check,
    assert_not_zero,
    uint256_mul
)
from contracts.interfaces.IggProfiles import IggProfiles

from contracts.tokens.ERC20.IERC20 import IERC20
from contracts.tokens.ERC721.IERC721 import IERC721
from contracts.tokens.ERC1155.IERC1155 import IERC1155

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
    member reward_type : felt
    member reward_contract : felt
    member token_amount : Uint256
    member amount : Uint256
    member id : Uint256
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
func RewardAdded(reward : Reward):
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


namespace GgQuest:
    
    func get_additional_rewards{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (rewards_len : felt , rewards : Reward*):
        alloc_locals
        let (rewards_len) = Additional_Rewards_Len.read()
        let (local rewards_array : Reward*) = alloc()
        local start = 0
        let stop = rewards_len
        # to add a check if its zero
        
        get_additional_rewards_loop{rewards_array=rewards_array, stop=stop}(start)
        return (rewards_len=rewards_len, rewards=rewards_array)
    end

    
    func get_players{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (players_len : felt, players : felt*):
        alloc_locals
        let (players_len) = Players_Len.read()
        let (local players_array : felt*) = alloc()
        local start = 0
        let stop = players_len
        # to add a check if its zero

        get_players_loop{players_array=players_array, stop=stop}(start)
        return (players_len=players_len, players=players_array)
    end


    
    func get_quest_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    )-> (res : felt):
        let (metadata_URL) = Metadata_URL.read()
        return (res=metadata_URL)
    end

    
    func is_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        operator : felt
    ) -> (res : felt):
        let (res) = Operators.read(operator)
        return (res)
    end

    
    func get_active{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (res : felt):
        let (res) = Is_Active.read()
        return (res)
    end

    
    func is_completed_by{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        address : felt
    ) -> (res : felt):
        let (completed_by) = Completed_By.read(address)
        return (res=completed_by)
    end

    
    func get_ggProfile_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    )-> (res : felt):
        let (contract) = Profiles.read()
        return (res=contract)
    end

    
    func get_reputation_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    )-> (res : felt):
        let (reputation_reward) = Reputation_Reward.read()
        return (res=reputation_reward)
    end

    
    func add_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        operator : felt
    ):
        Operators.write(operator, 1)
        OperatorAdded.emit(operator)

        return ()
    end

    
    func remove_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        operator : felt
    ):
        Operators.write(operator, TRUE)
        OperatorRemoved(operator)

        return ()
    end

    
    func add_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        reward : Reward
    ) -> (res : felt):
        alloc_locals

        let (active) = Is_Active.read()
        with_attr error_message("Rewards cannot be added after quest activation"):
            assert active = FALSE
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

        RewardAdded.emit(reward)

        return (res=rewards_len - 1)
    end

    
    func send_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        player : felt
    ):   
        alloc_locals

        let (completed_by) = Completed_By.read(address=player)
        with_attr error_message("Quest already completed by this player"):
            assert completed_by = FALSE
        end
        local start = 0
        let (rewards_len) = Additional_Rewards_Len.read()
        let stop = rewards_len
        local had_at_least_one_reward = FALSE
        send_reward_loop{
            player=player, 
            stop=stop, 
            had_at_least_one_reward=had_at_least_one_reward
        }(start)
        with_attr error_message("All rewards have already been distributed"):
            assert had_at_least_one_reward = TRUE
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

    
    func increase_reward_amount{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : Uint256, reward : Reward
    ):
        alloc_locals
        local start = 0
        let (rewards_len) = Additional_Rewards_Len.read()
        let stop = rewards_len
        local exists = FALSE
        increase_reward_token_loop{stop=stop, amount=amount, reward=reward, exists=exists}(start)
        with_attr error_message("Given reward (token address) doesn't exist for this quest"):
            assert exists = TRUE
        end
        return ()
    end

    
    func update_reputation_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_value : felt
    ):
        Reputation_Reward.write(new_value)
        ReputationRewardUpdated.emit(new_value)
        return ()
    end

    
    func activate_quest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ):
        Is_Active.write(TRUE)
        QuestActivated.emit()
        return ()
    end

    
    func deactivate_quest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        withdrawal_address : felt
    ):
        alloc_locals

        Is_Active.write(FALSE)
        # transfer all tokens
        local start = 0
        let (rewards_len) = Additional_Rewards_Len.read()
        let stop = rewards_len
        deactivate_loop{stop=stop, withdrawal_address=withdrawal_address}(start)
        QuestDeactivated.emit()
        return ()
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
        let (low, high) = uint256_mul(reward.token_amount, reward.amount)
        # todo : i assume low contains the product on 128 bits
        local product : Uint256 = low
        with_attr error_message("ggQuest contract doesn't own enough tokens"):
            let (enough) = uint256_le(product, balance)
            assert_not_zero(enough)
        end
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else: 
        if reward.reward_type == RewardType.ERC721:
            let (owner) = IERC721.ownerOf(contract_address=reward.reward_contract, token_id=reward.id)
            with_attr error_message("ggQuests contract doesn't own this ERC721 token"):
                assert owner = contract_address
            end

            with_attr error_message("tokenAmount and amount should be 1 as ERC721 is unique"):
                assert reward.token_amount = Uint256(1, 0)
            end

            with_attr error_message("tokenAmount and amount should be 1 as ERC721 is unique"):
                assert reward.amount = Uint256(1, 0)
            end

            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            let (balance : Uint256) = IERC1155.balanceOf(contract_address=reward.reward_contract, owner=contract_address)
            let (low,high) = uint256_mul(reward.token_amount, reward.amount)
            # todo
            local product : Uint256 = low
            with_attr error_message("ggQuests contract doesn't own enough tokens"):
                let (enough) = uint256_le(product, balance)
                assert_not_zero(enough)
            end

            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return ()

end


func withdraw_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reward_id : felt, withdrawal_address : felt
):
    let (additional_reward) = Additional_Rewards.read(reward_id)
    let reward_type = additional_reward.reward_type
    let reward_contract = additional_reward.reward_contract

    let (contract_address) = get_contract_address()

    if reward_type == RewardType.ERC20 :
        let (balance : Uint256) = IERC20.balanceOf(contract_address=reward_contract, account=contract_address)
        let (success) = IERC20.transfer(contract_address=reward_contract,recipient= withdrawal_address, amount=balance)
        with_attr error_message("transfer ERC20 failed"):
           assert_not_zero(success)
        end
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        
        let amount = additional_reward.id

        if reward_type ==  RewardType.ERC721 :
            IERC721.transferFrom(
                contract_address=reward_contract, 
                _from=contract_address, 
                to=withdrawal_address,
                token_id=amount
            )
            #with_attr error_message("transfer ERC721 failed"):
               # assert_not_zero(success)
            #end
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr

        else:
            let (balance : Uint256) = IERC1155.balanceOf(
                contract_address=reward_contract,
                owner=contract_address
            )
            # todo
            #IERC1155.safeTransferFrom(
               # contract_address=reward_contract,
                #_from=contract_address,
               # to=withdrawal_address,
               # token_id=amount,
               # data_len=balance,
               # 0
            #)
            #with_attr error_message("transfer ERC1155 failed"):
                #assert_not_zero(success)
            #end
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return ()
end

############
#  INTERNAL 
############
func _uint_to_felt{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (value: Uint256) -> (value: felt):
    assert_lt_felt(value.high, 2**123)
    return (value.high * (2 ** 128) + value.low)
end

func _reward_hash{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*, }(
    reward : Reward
) -> (bytes : Uint256):
    alloc_locals
    let (local elements : felt*) = alloc()
    let (casted : felt) =  _uint_to_felt(reward.id)
    assert [elements] = reward.reward_contract
    assert [elements + 1] = casted

    let keccak_ptr : felt* = alloc()
    local keccak_ptr_start : felt* = keccak_ptr

    with keccak_ptr :
        let (keccak_hash) = keccak_felts(n_elements=2, elements=elements)
    end

    finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr)
    return (bytes=keccak_hash)
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

    withdraw_reward(start, withdrawal_address)

    return deactivate_loop(start + 1)
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

    return verify_uniqueness_of_rewards_loop(start + 1)
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
        tempvar exists = TRUE
        let (local reward_test : Reward) = Additional_Rewards.read(start)
        let (players_len) = Players_Len.read()
        let (local amount_test) = reward_test.amount + amount - players_len
        
        _verifyTokenOwnershipFor(reward_test)
        local new_reward : Reward
        assert new_reward.reward_type = additional_reward.reward_type
        assert new_reward.reward_contract = additional_reward.reward_contract
        assert new_reward.token_amount = additional_reward.token_amount
        assert new_reward.amount = additional_reward.amount + amount
        assert new_reward.id = additional_reward.id
           
        Additional_Rewards.write(start, new_reward)       
    end
    return increase_reward_token_loop(start + 1)
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
        tempvar had_at_least_one_reward = TRUE
        let token_address = reward.reward_contract

        if reward.reward_type == RewardType.ERC20:
            IERC20.transfer(contract_address=token_address, player, reward.token_amount)
        else:
            if reward.reward_type == RewardType.ERC721:
            let (contract_add) = get_contract_address()
                IERC721.safeTransferFrom(contract_address=token_address, contract_add, player, reward.reward_id)
            else :
                IERC1155.safeTransferFrom(contract_address=token_address, contract_add, player, reward.reward_id, reward.token_amount, 0)
            end
        end
    end
   return send_reward_loop(start + 1)

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

    return get_additional_rewards_loop(start + 1)
end

func get_players_loop{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    players_array : felt*,
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

    return get_players_loop(start + 1)
end
