%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address
)
from starkware.cairo.common.bool import TRUE, FALSE

from starkware.cairo.common.uint256 import (
    Uint256, 
    uint256_add,
    uint256_sub,
    uint256_mul,
    uint256_le,
    uint256_lt,
    uint256_check,
    assert_not_zero as uint_256_assert_not_zero
)

from starkware.cairo.common.math import (
    assert_not_zero
)


from contracts.ggQuest.library import (
    GgQuest,
    Reward,
    Reputation_Reward,
    Metadata_URL,
    Profiles,
    Operators
)

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
   return GgQuest.get_additional_rewards()
end

@view
func get_players{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (players_len : felt, players : felt*):
    return GgQuest.get_players()
end


@view
func get_quest_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):
    return GgQuest.get_quest_URI()  
end

@view
func is_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
) -> (res : felt):
    return GgQuest.is_operator(operator)  
end

@view
func get_active{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (res : felt):
    return GgQuest.get_active()  
end

@view
func is_completed_by{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
) -> (res : felt):
    return GgQuest.is_completed_by(address)  
end

@view
func get_ggProfile_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):
    return GgQuest.get_ggProfile_address()  
end

@view
func get_reputation_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):
    return GgQuest.get_reputation_reward()  
end

############
#  EXTERNAL 
############

@external
func add_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):
    assert_only_operator()
    GgQuest.add_operator(operator)
    return ()
end

@external
func remove_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):
    assert_only_operator()
    GgQuest.remove_operator(operator)
    return ()
end
 
@external
func add_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    reward : Reward
) -> (res : felt):
    assert_only_operator()

   return GgQuest.add_reward(reward)
end

@external
func send_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    player : felt
):   
    assert_only_operator()
    GgQuest.send_reward(player)
    return () 
end

@external
func increase_reward_amount{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    amount : felt, reward : Reward
):
    GgQuest.increase_reward_amount(amount, reward)
    return ()
end

@external
func update_reputation_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_value : felt
):
    assert_only_operator()
    GgQuest.update_reputation_reward(new_value)
    return ()
end

@external
func activate_quest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
):
    assert_only_operator()
    GgQuest.activate_quest()
    return ()
end

@external
func deactivate_quest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    withdrawal_address : felt
):
    assert_only_operator()
    GgQuest.deactivate_quest(withdrawal_address)
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
        assert is_op = TRUE
    end
    return ()
end