%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc


from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address
)
from starkware.cairo.common.math_cmp import (
    is_not_zero
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
func third_parties_len() -> (len : felt):
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

# linked third party per user_address
@storage_var
func linked_third_party_per_user(user_address : felt, index : felt) -> (third_party : ThirdParty):
end

@storage_var
func linked_third_party_per_user_len(user_address : felt) -> (len : felt):
end

############
#  EVENTS 
############

@event
func minted(user_address : felt, pseudo : felt):
end

@event
func burned(user_address : felt):
end

@event
func updated(user_address : felt, pseudo : felt):
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
func third_party_linked_to_profile(user_address : felt, third_party_id : felt, third_party_user_id : felt):
end

@event
func third_party_unlinked_to_profile(user_address : felt, third_party_id : felt):
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
    let (caller) = get_caller_address()
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
    let gained_reputation = profile_data.gained_reputation
    let lost_reputation = profile_data.lost_reputation
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


@view
func get_registered_addresses{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (registered_addresses_len : felt, registered_addresses : felt* ):

    alloc_locals
    let (registered_addresses_len) = registered_addresses_len.read()
    let (local registered_addresses_array : felt*) = alloc()
    let (local start) = 0
    let stop = registered_addresses_len
    # to add a check if its zero

    _get_registered_addresses{registered_addresses=registered_addresses_array, stop=stop}(start)
    return (registered_addresses_len=registered_addresses_len, registered_addresses=registered_addresses_array)
end

@view 
func get_third_parties{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (third_parties_len : felt, third_parties : felt*):
    alloc_locals
    let (third_parties_len) = third_parties_len.read()
    let (local third_parties : felt*) = alloc()
    let stop = third_parties_len
    let (local start) = 0
    _get_third_parties{stop=stop, array=third_parties}(start)
    return (third_parties_len, third_parties)
end

############
#  EXTERNAL 
############

@external
func add_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):  
    assert_only_operator()
    operators.write(operator, 1)
    operator_added(operator)
    return ()
end

@external
func remove_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):  
    assert_only_operator()
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

    #to check
    #let (new_user_data : ProfileData) = ProfileData(
      #  profile_data.pseudo,
      #  profile_data.profile_picture_URL, 
      #  profile_data.cover_picture_URL, 
       # 1 ,
       # profile_data.gained_reputation, 
       # profile_data.lost_reputation
    #)

    #profiles.write(caller, new_user_data)
    minted.emit(caller, user_data.pseudo)
    return ()
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
):  
    assert_only_operator()

    let (profile) = profiles.read(user_address)
    taken_pseudonymes.write(profile.pseudo, 0)

    let (null_object : ProfileData) = ProfileData(0,0,0,0,0,0)
    profiles.write(user_address, null_object)

    burned.emit(user_address)
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

    updated.emit(caller, user_data.pseudo)
    return ()
end

@external
func increase_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, amount : felt
):
    assert_only_operator()

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
    reputation_increased.emit(user_address, amount)
    return ()
end

@external
func decrease_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, amount : felt
):
    assert_only_operator()

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
        profile_data.lost_reputation - amount
    )

    profiles.write(user_address, new_user_data)
    reputation_decreased.emit(user_address, amount)
    return ()
end

@external 
func add_third_party{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    third_party_name : felt
):
    assert_only_operator()
    let (index) = third_parties_len.read()
    third_parties.write(index, third_party_name)
    add_supported_third_party.emit(third_party_name)
    return ()
end

#todo
@external
func link_third_party_to_profile{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    profile_address : felt, third_party_id : felt, third_party_user_id : felt 
):
    assert_only_operator()
    let (party) = third_parties.read(third_party_id)
    with_attr error_message("No third party found with this ID"):
        is_not_zero(party)
    end
    let (len_linked_third_parties) = linked_third_party_per_user_len.read(profile_address)
    let (local start) = 0
    let stop = len_linked_third_parties
    _assert_not_already_linked{stop=stop, third_party_id=third_party_id, profile_address=profile_address}(start)
    let (new_third_party : ThirdParty) = ThirdParty(
        third_party_id,
        third_party_user_id
    )
    linked_third_party_per_user.write(profile_address, len_linked_third_parties, new_third_party)
    linked_third_party_per_user_len.write(profile_address, len_linked_third_parties + 1)
    third_party_linked_to_profile.emit(profile_address, third_party_id, third_party_user_id)

    return ()
end

#todo
@external
func unlink_third_party_to_profile{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    profile_address : felt, third_party_id : felt
):
    assert_only_operator()
    let (party) = third_parties.read(third_party_id)
    with_attr error_message("No third party found with this ID"):
        is_not_zero(party)
    end

    let (local removed) = 0
    local removed_index
    let (len_linked_third_parties) = linked_third_party_per_user_len.read(profile_address)
    let (local start) = 0
    let stop = len_linked_third_parties

    _verify_third_party_found{removed=removed, removed_index=removed_index, stop=stop}(start)

    if removed == 1:    
        let (last_item) = linked_third_party_per_user.read(profile_address, len_linked_third_parties - 1)
        linked_third_party_per_user.write(profile_address, removed_index, last_item)
        # pop the last item of the array
        linked_third_party_per_user.write(profile_address, len_linked_third_parties - 1, 0)

        linked_third_party_per_user_len.write(profile_address, len_linked_third_parties - 1)
    end


    third_party_unlinked_to_profile.emit(profile_address, third_party_id)

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
        is_not_zero(caller)
    end
    let (is_op) = operators.read(caller)
    with_attr error_message("only operators can call this function"):
        assert is_op = 1
    end
end

############
#  INTERNAL 
############

func _assert_not_already_linked{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr,
    stop : felt, 
    third_party_id : felt, 
    profile_address : felt
}(start : felt):

end

func _verify_third_party_found{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr,
    removed : felt,
    removed_index : felt,
    profile_address : felt,
    third_party_id : felt,
    stop : felt, 
}(start : felt):
    if start == stop :
        return ()
    end

    let (third_party) = linked_third_party_per_user.read(profile_address, start)
    if third_party.third_party_id == third_party_id:
        removed = 1
        removed_index = start
        # maybe change by popping the last item
        linked_third_party_per_user.write(profile_address, start, 0)
        return ()
    end
    _verify_third_party_found(start + 1)
end

func _set_user_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, user_data : UpdatableByUserData
):  
    let (current_data) = profiles.read(user_address)
    let current_pseudo = current_data.pseudo
    let new_pseudo = user_data.pseudo

    # todo : finish the body 

    let (caller) = get_caller_address()
    let (updated_data : ProfileData) = ProfileData(
        new_pseudo,
        user_data.profile_picture_URL, 
        user_data.cover_picture_URL, 
        current_data.is_registered ,
        current_data.gained_reputation, 
        current_data.lost_reputation
    )

    taken_pseudonymes.write(new_pseudo, 1)
    profiles.write(caller, updated_data)
    return ()
end

func _get_registered_addresses{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    registered_addresses_array : felt*,
    stop : felt,
}(start : felt):
    if start == stop:
        return ()
    end

    let (registered_address : felt) = registered_addresses.read(start)
    assert [registered_addresses + start] = registered_address
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    _get_registered_addresses(start + 1)

end

func _get_third_parties{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    stop : felt,
    array : felt*
}(start : felt):
    if start == stop :
        return ()
    end 

    let (third_party) = third_parties.read(start)
    assert [array + start] = third_party
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    _get_third_parties(start + 1)

end