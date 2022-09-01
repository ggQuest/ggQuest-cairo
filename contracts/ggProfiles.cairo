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
from starkware.cairo.common.math import assert_not_equal



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
func Profiles(address : felt) -> (profile_data : ProfileData):
end

@storage_var
func Taken_Pseudonymes(pseudo : felt) -> (is_taken : felt):
end

@storage_var
func Registered_Addresses(address : felt) -> (res : felt):
end

@storage_var
func Registered_Addresses_Len() -> (res : felt):
end

@storage_var
func Third_Parties(index : felt) -> (party : felt):
end

@storage_var
func Third_Parties_Len() -> (len : felt):
end

@storage_var
func Name() -> (res : felt):
end

@storage_var
func Ticker() -> (res : felt):
end

@storage_var
func Operators(address : felt) -> (is_operator : felt):
end

# linked third party per user_address
@storage_var
func Linked_Third_Party_Per_User(user_address : felt, index : felt) -> (third_party : ThirdParty):
end

@storage_var
func Linked_Third_Party_Per_User_Len(user_address : felt) -> (len : felt):
end

############
#  EVENTS 
############

@event
func Minted(user_address : felt, pseudo : felt):
end

@event
func Burned(user_address : felt):
end

@event
func Updated(user_address : felt, pseudo : felt):
end

@event
func ReputationIncreased(user_address : felt, amount : felt):
end

@event
func ReputationDecreased(user_address : felt, amount : felt):
end

@event
func OperatorAdded(operator_address : felt):
end

@event
func OperatorRemoved(operator_address : felt):
end

@event
func AddSupportedThirdParty(name : felt):
end

@event
func ThirdPartyLinkedToProfile(user_address : felt, third_party_id : felt, third_party_user_id : felt):
end

@event
func ThirdPartyUnlinkedToProfile(user_address : felt, third_party_id : felt):
end

############
#  CONSTRUCTOR 
############

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _name : felt, _ticker : felt
):
    Name.write(_name)
    Ticker.write(_ticker)
    let (caller) = get_caller_address()
    Operators.write(caller, 1)
    return ()
end


############
#  VIEW 
############

@view
func get_is_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
) -> (res : felt):
    let (is_op) = Operators.read(operator)
    return (res=is_op)
end

@view
func get_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (gained_reputation : felt, lost_reputation : felt):
    let (profile_data) = Profiles.read(user_address)
    let gained_reputation = profile_data.gained_reputation
    let lost_reputation = profile_data.lost_reputation
    return (gained_reputation=gained_reputation, lost_reputation=lost_reputation)
end

@view
func get_profile_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (profile_data : ProfileData):
    let (profile_data) = Profiles.read(user_address)
    return (profile_data=profile_data)
end

@view
func get_is_available{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    pseudo : felt
) -> (res : felt):
    let (is_taken) = Taken_Pseudonymes.read(pseudo)
    if is_taken == 1:
        return (res=0)
    end
    return (res=1)
end

@view
func has_profile_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (res : felt):
    let (profile_data) = Profiles.read(user_address)
    return (res=profile_data.is_registered)
end


@view
func get_registered_addresses{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (registered_addresses_len : felt, registered_addresses : felt* ):

    alloc_locals
    let (len) = Registered_Addresses_Len.read()
    let (local registered_addresses_array : felt*) = alloc()
    local start = 0
    let stop = len
    # to add a check if its zero

    get_registered_addresses_loop{registered_addresses_array=registered_addresses_array, stop=stop}(start)
    return (registered_addresses_len=len, registered_addresses=registered_addresses_array)
end

@view 
func get_third_parties{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (third_parties_len : felt, third_parties : felt*):
    alloc_locals
    let (len) = Third_Parties_Len.read()
    let (local third_parties : felt*) = alloc()
    let stop = len
    local start = 0
    get_third_parties_loop{stop=stop, array=third_parties}(start)
    return (third_parties_len=len, third_parties=third_parties)
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
    OperatorRemoved.emit(operator)
    return ()
end

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_data : UpdatableByUserData
):
    alloc_locals
    let (caller) = get_caller_address()
    let (profile_data) = Profiles.read(caller)
    let is_registered = profile_data.is_registered
    with_attr error_message("Profile already registered"):
        assert is_registered = 0
    end
    _set_user_data(caller, user_data)

    Minted.emit(caller, user_data.pseudo)
    return ()
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
):     
    alloc_locals
    assert_only_operator()

    let (profile) = Profiles.read(user_address)
    Taken_Pseudonymes.write(profile.pseudo, 0)

    local null_account : ProfileData
    assert null_account.pseudo = 0
    assert null_account.profile_picture_URL = 0
    assert null_account.cover_picture_URL = 0
    assert null_account.is_registered = 0
    assert null_account.gained_reputation = 0
    assert null_account.lost_reputation = 0

    Profiles.write(user_address, null_account)

    Burned.emit(user_address)
    return ()   
end

@external
func update{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_data : UpdatableByUserData
):
    alloc_locals
    let (local caller) = get_caller_address()
    let (profile_data) = Profiles.read(caller)
    let is_registered = profile_data.is_registered
    with_attr error_message("Profile not registered, please mint first"):
        assert is_registered = 1
    end
    _set_user_data(caller, user_data)

    Updated.emit(caller, user_data.pseudo)
    return ()
end

@external
func increase_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, amount : felt
):
    alloc_locals
    assert_only_operator()

    # check profile is registered
    let (profile_data) = Profiles.read(user_address)
    let is_registered = profile_data.is_registered
    with_attr error_message("Profile not registered"):
        assert is_registered = 1
    end

    local new_user_data : ProfileData 
    assert new_user_data.pseudo = profile_data.pseudo
    assert new_user_data.profile_picture_URL = profile_data.profile_picture_URL
    assert new_user_data.cover_picture_URL = profile_data.cover_picture_URL
    assert new_user_data.is_registered = profile_data.is_registered
    assert new_user_data.gained_reputation = profile_data.gained_reputation + amount
    assert new_user_data.lost_reputation = profile_data.lost_reputation


    Profiles.write(user_address, new_user_data)
    ReputationIncreased.emit(user_address, amount)
    return ()
end

@external
func decrease_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, amount : felt
):
    alloc_locals
    assert_only_operator()

    # check profile is registered
    let (profile_data) = Profiles.read(user_address)
    let is_registered = profile_data.is_registered
    with_attr error_message("Profile not registered"):
        assert is_registered = 1
    end

    local new_user_data : ProfileData 
    assert new_user_data.pseudo = profile_data.pseudo
    assert new_user_data.profile_picture_URL = profile_data.profile_picture_URL
    assert new_user_data.cover_picture_URL = profile_data.cover_picture_URL
    assert new_user_data.is_registered = profile_data.is_registered
    assert new_user_data.gained_reputation = profile_data.gained_reputation + amount
    assert new_user_data.lost_reputation = profile_data.lost_reputation

    Profiles.write(user_address, new_user_data)
    ReputationDecreased.emit(user_address, amount)
    return ()
end

@external 
func add_third_party{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    third_party_name : felt
):
    assert_only_operator()
    let (index) = Third_Parties_Len.read()
    Third_Parties.write(index, third_party_name)
    AddSupportedThirdParty.emit(third_party_name)
    return ()
end

#todo
@external
func link_third_party_to_profile{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    profile_address : felt, third_party_id : felt, third_party_user_id : felt 
):
    alloc_locals

    assert_only_operator()
    let (party) = Third_Parties.read(third_party_id)
    with_attr error_message("No third party found with this ID"):
        is_not_zero(party)
    end
    let (len_linked_third_parties) = Linked_Third_Party_Per_User_Len.read(profile_address)
    local start = 0
    let stop = len_linked_third_parties

    assert_not_already_linked_loop{
        stop=stop, 
        third_party_id=third_party_id, 
        profile_address=profile_address
    }(start)
    
    local new_third_party : ThirdParty
    assert new_third_party.third_party_id = third_party_id
    assert new_third_party.user_id = third_party_user_id

    Linked_Third_Party_Per_User.write(profile_address, len_linked_third_parties, new_third_party)
    Linked_Third_Party_Per_User_Len.write(profile_address, len_linked_third_parties + 1)
    ThirdPartyLinkedToProfile.emit(profile_address, third_party_id, third_party_user_id)

    return ()
end

#todo
@external
func unlink_third_party_to_profile{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    profile_address : felt, third_party_id : felt
):
    alloc_locals
    assert_only_operator()
    let (party) = Third_Parties.read(third_party_id)
    with_attr error_message("No third party found with this ID"):
        is_not_zero(party)
    end

    local removed = 0
    local removed_index
    let (len_linked_third_parties) = Linked_Third_Party_Per_User_Len.read(profile_address)
    local start = 0
    let stop = len_linked_third_parties

    verify_third_party_found_loop{
        removed=removed, 
        removed_index=removed_index,
        profile_address=profile_address, 
        third_party_id=third_party_id, 
        stop=stop
    }(start)

    if removed == 1:    
        let (last_item) = Linked_Third_Party_Per_User.read(profile_address, len_linked_third_parties - 1)
        Linked_Third_Party_Per_User.write(profile_address, removed_index, last_item)
        # pop the last item of the array
        local null_third_party : ThirdParty
        assert null_third_party.third_party_id = 0
        assert null_third_party.user_id = 0
        Linked_Third_Party_Per_User.write(profile_address, len_linked_third_parties - 1, null_third_party)

        Linked_Third_Party_Per_User_Len.write(profile_address, len_linked_third_parties - 1)
    end

    ThirdPartyUnlinkedToProfile.emit(profile_address, third_party_id)

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
    let (is_op) = Operators.read(caller)
    with_attr error_message("only operators can call this function"):
        assert is_op = 1
    end
end

############
#  INTERNAL 
############

func assert_not_already_linked_loop{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr,
    stop : felt, 
    third_party_id : felt, 
    profile_address : felt
}(start : felt):
    if start==stop:
        return ()
    end

    let (third_party : ThirdParty) = Linked_Third_Party_Per_User.read(profile_address, start)
    with_attr error_message("This profile is already linked to this third party"):
        assert_not_equal(third_party.third_party_id, third_party_id)
    end

    assert_not_already_linked_loop(start + 1)
end

func verify_third_party_found_loop{
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

    let (third_party : ThirdParty) = Linked_Third_Party_Per_User.read(profile_address, start)
    if third_party.third_party_id == third_party_id:
        removed = 1
        removed_index = start
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        # maybe change by popping the last item
        Linked_Third_Party_Per_User.write(profile_address, start, 0)
        return ()
    end

    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr
    
    verify_third_party_found_loop(start + 1)
end

func _set_user_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, user_data : UpdatableByUserData
):  
    let (current_data) = Profiles.read(user_address)
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

    Taken_Pseudonymes.write(new_pseudo, 1)
    Profiles.write(caller, updated_data)
    return ()
end

func get_registered_addresses_loop{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    registered_addresses_array : felt*,
    stop : felt,
}(start : felt):
    if start == stop:
        return ()
    end

    let (registered_address : felt) = Registered_Addresses.read(start)
    assert [registered_addresses_array + start] = registered_address
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    get_registered_addresses_loop(start + 1)

end

func get_third_parties_loop{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    stop : felt,
    array : felt*
}(start : felt):
    if start == stop :
        return ()
    end 

    let (third_party) = Third_Parties.read(start)
    assert [array + start] = third_party
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    get_third_parties_loop(start + 1)

end