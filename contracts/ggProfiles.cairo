%lang starknet

from starware.cairo.common.cairo_builtins import HashBuiltin


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
    assert_not_zero
)


############
#  STRUCTS 
############

struct UpdatableByUserData:
    member pseudo : felt
    member profile_picture_URL : felt
    member cover_picture_URL : felt
end

struct ProfileData:
    # Data of the user
    member pseudo : felt
    member profile_picture_URL : felt
    member cover_picture_URL : felt
    member is_registered : felt

    # Reputation

    member gained_reputation : felt
    member lost_reputation : felt

    #todo :  third partied
end

struct ThirdParty:
    member third_party_id : felt
    member user_id : felt
end

############
#  STORAGE 
############

@storage_var
func profiles(address : felt) -> (profile_data : ProfileData):
end

@storage_var
func taken_pseudonymes(pseudo : felt) -> (is_taken : felt):
end

@storage_var
func registered_addresses(address : felt) -> (res : felt):
end

@storage_var
func registered_addresses_len() -> (res : felt):
end

@storage_var
func third_parties(index : felt) -> (party : felt):
end

@storage_var
func name() -> (res : felt):
end

@storage_var
func ticker() -> (res : felt):
end

@storage_var
func operators(address : felt) -> (is_operator : felt):
end

############
#  EVENTS 
############

@event
func mint(user_address : felt, pseudo : felt):
end

@event
func burn(user_address : felt):
end

@event
func update(user_address : felt, pseudo : felt):
end

@event
func reputation_increased(user_address : felt, amount : felt):
end

@event
func reputation_decreased(user_address : felt, amount : felt):
end

@event
func operator_added(operator_address : felt):
end

@event
func operator_removed(operator_address : felt):
end

@event
func add_supported_third_party(name : felt):
end

@event
func link_third_part_to_profile(user_address : felt, third_party_id : felt, third_party_user_id : felt):
end

@event
func unlink_third_part_to_profile(user_address : felt, third_party_id : felt):
end

############
#  CONSTRUCTOR 
############

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _name : felt, _ticker : felt
):
    name.write(_name)
    ticker.write(_ticker)
    let (caller) = get_caller_address
    operators.write(caller, 1)
    return ()
end





############
#  VIEW 
############

@view
func get_is_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
) -> (res : felt):
    let (is_op) = operators.read(operator)
    return (res=is_op)
end

@view
func get_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (reputation : felt):
    
end

@view
func get_profile_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (profile_data : ProfileData):
    
end

@view
func get_is_available{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    pseudo : felt
) -> (res : felt):
    
end

@view
func has_profile_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (res : felt):
    
end

#todo 
@view
func get_third_parties{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (res : felt):
    
end

############
#  EXTERNAL 
############

@external
func add_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):  
    let (caller) = get_caller_address
    with_attr error_message("Only operators can manage operators"):
    let (is_operator) = operators.read(caller)
        assert is_operator = 1
    end
    operators.write(operator, 1)
    operator_added(operator)
    return ()
end

@external
func remove_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):  
    let (caller) = get_caller_address
    with_attr error_message("Only operators can manage operators"):
    let (is_operator) = operators.read(caller)
        assert is_operator = 1
    end
    operators.write(operator, 0)
    operator_removed(operator)
    return ()
end

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_data : UpdatableByUserData
):
    return ()
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
):
    return ()
end

@external
func update{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_data : UpdatableByUserData
):
    return ()
end

@external
func increase_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, amount : felt
):
    return ()
end

@external
func decrease_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, amount : felt
):
    return ()
end

@external 
func add_third_party{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
):

end

@external
func link_third_party_to_profile{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    profile_address : felt, third_party_id : felt, third_party_user_id : felt 
):

    return ()
end

@external
func unlink_third_party_to_profile{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    profile_address : felt, third_party_id : felt
):

    return ()
end


############
#  INTERNAL 
############

func _set_user_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, user_data : UpdatableByUserData
):

    return ()
end