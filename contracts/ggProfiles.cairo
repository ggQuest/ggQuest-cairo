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
func increase_reputation(user_address : felt, amount : felt):
end

@event
func decrease_reputation(user_address : felt, amount : felt):
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
func get_is_operator(operator : felt) -> (res : felt):
    let (is_op) = operators.read(operator)
    return (res=is_op)
end

############
#  EXTERNAL 
############

@external
func add_operator{}(
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
func remove_operator{}(
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

