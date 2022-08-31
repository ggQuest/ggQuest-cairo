%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin


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
) -> (gained_reputation : felt, lost_reputation : felt):
    let (profile_data) = profiles.read(user_address)
    let (gained_reputation) = profile_data.gained_reputation
    let (lost_reputation) = profile_data.lost_reputation
    return (gained_reputation=gained_reputation, lost_reputation=lost_reputation)
end

@view
func get_profile_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (profile_data : ProfileData):
    let (profile_data) = profiles.read(user_address)
    return (profile_data=profile_data)
end

@view
func get_is_available{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    pseudo : felt
) -> (res : felt):
    let (is_taken) = taken_pseudonymes.read(pseudo)
    if is_taken == 1:
        return (res=0)
    end
    return (res=1)
end

@view
func has_profile_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (res : felt):
    let (profile_data) = profiles.read(user_address)
    return (res=profile_data.is_registered)
end

#todo 
@view
func get_third_parties{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (res : felt):
    
end

@view
func get_registered_addresses{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (registered_addresses_len : felt, registered_addresses : felt* ):

    alloc_locals
    let (registered_addresses_len) = registered_addresses_len.read()
    let (local registered_addresses_array : felt*) = alloc()
    let start = Uint256(0,0)
    let stop = registered_addresses_len
    local index_start = 0
    # to add a check if its zero

    _get_registered_addresses{registered_addresses=registered_addresses_array, index_start=index_start, stop=stop}(start)
    return (registered_addresses_len=registered_addresses_len, registered_addresses=registered_addresses_array)
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
    alloc_locals
    let (caller) = get_caller_address()
    let (profile_data) = profiles.read(caller)
    let (is_registered) = profile_data.is_registered
    with_attr error_message("Profile already registered"):
        assert is_registered = 0
    end
    _set_user_data(caller, user_data)
    let (new_user_data : ProfileData) = ProfileData(
        profile_data.pseudo,
        profile_data.profile_picture_URL, 
        profile_data.cover_picture_URL, 
        1 ,
        profile_data.gained_reputation, 
        profile_data.lost_reputation
    )

    profiles.write(caller, new_user_data)
    mint.emit(caller, user_data.pseudo)
    return ()
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
):  
    let (caller) = get_caller_address()
    let (is_op) = operators.read(caller)
    with_attr error_message("Only operators have rights to delete users' data"):
        assert is_op = 1
    end

    let (null_object) = ProfileData(0,0,0,0,0,0)
    profiles.write(user_address, null_object)
    burn.emit(user_address)
    return ()   
end

@external
func update{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_data : UpdatableByUserData
):
    let (caller) = get_caller_address()
    let (profile_data) = profiles.read(caller)
    let (is_registered) = profile_data.is_registered
    with_attr error_message("Profile not registered, please mint first"):
        assert is_registered = 1
    end
    _set_user_data(caller, user_data)

    update.emit(caller, user_data.pseudo)
    return ()
end

@external
func increase_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, amount : felt
):
    let (caller) = get_caller_address()
    # check caller is operator 
    let (is_op) = operators.read(caller)
    with_attr error_message("Only operators can manage reputation"):
        assert is_op = 1
    end

    # check profile is registered
    let (profile_data) = profiles.read(user_address)
    let (is_registered) = profile_data.is_registered
    with_attr error_message("Profile not registered"):
        assert is_registered = 1
    end

    let (new_user_data : ProfileData) = ProfileData(
        profile_data.pseudo,
        profile_data.profile_picture_URL, 
        profile_data.cover_picture_URL, 
        1 ,
        profile_data.gained_reputation + amount, 
        profile_data.lost_reputation
    )

    profiles.write(user_address, new_user_data)
    reputation_increased(user_address, amount)
    return ()
end

@external
func decrease_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, amount : felt
):
    let (caller) = get_caller_address()
    # check caller is operator 
    let (is_op) = operators.read(caller)
    with_attr error_message("Only operators can manage reputation"):
        assert is_op = 1
    end

    # check profile is registered
    let (profile_data) = profiles.read(user_address)
    let (is_registered) = profile_data.is_registered
    with_attr error_message("Profile not registered"):
        assert is_registered = 1
    end

    let (new_user_data : ProfileData) = ProfileData(
        profile_data.pseudo,
        profile_data.profile_picture_URL, 
        profile_data.cover_picture_URL, 
        1 ,
        profile_data.gained_reputation, 
        profile_data.lost_reputation - amounts
    )

    profiles.write(user_address, new_user_data)
    reputation_decreased(user_address, amount)
    return ()
end

#todo
@external 
func add_third_party{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
):

end

#todo
@external
func link_third_party_to_profile{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    profile_address : felt, third_party_id : felt, third_party_user_id : felt 
):

    return ()
end

#todo
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
    let (current_data) = profiles.read(user_address)
    let current_pseudo = current_data.pseudo
    let (new_pseudo) = user_data.pseudo

    # todo : finish the body 

    let (caller) = get_caller_address()
    let (updated_data : ProfileData) = ProfileData(
        new_pseudo,
        user_data.profile_picture_URL, 
        user_data.cover_picture_URL, 
        current_data.is_registered ,
        current_data.gained_reputation, 
        current_data.lost_reputation - amounts
    )

    taken_psuedonymes.write(new_pseudo, 1)
    profiles.write(caller, updated_data)
    return ()
end

func _get_registered_addresses{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    registered_addresses_array : felt*,
    index_start : felt,
    stop : felt,
}(start : Uint256):
    let (is_end_of_loop) = uint256_le(stop,start)
    assert_not_zero(is_end_of_loop)

    let (registered_address : felt) = registered_addresses.read(start)
    assert [registered_addresses + index_start * Uint256.SIZE] = registered_address
    tempvar index_start = index_start + 1
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    let (next_start, _) = uint256_add(start, Uint256(1,0))
    _get_registered_addresses(next_start)

end