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

from starkware.cairo.common.bool import TRUE, FALSE

from contracts.ggProfiles.library import (
    GgProfiles,
    Name,
    Ticker,
    Operators,
    ProfileData,
    UpdatableByUserData
)


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
    Operators.write(caller, TRUE)
    return ()
end


############
#  VIEW 
############

@view
func get_is_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
) -> (res : felt):
    return GgProfiles.get_is_operator(operator)
end

@view
func get_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (gained_reputation : felt, lost_reputation : felt):
    return GgProfiles.get_reputation(user_address)
end

@view
func get_profile_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (profile_data : ProfileData):
    return GgProfiles.get_profile_data(user_address)
end

@view
func get_is_available{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    pseudo : felt
) -> (res : felt):
    return GgProfiles.get_is_available(pseudo)
end

@view
func has_profile_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (res : felt):
    return GgProfiles.has_profile_data(user_address)
end


@view
func get_registered_addresses{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (registered_addresses_len : felt, registered_addresses : felt* ):
    return GgProfiles.get_registered_addresses()
end

@view 
func get_third_parties{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (third_parties_len : felt, third_parties : felt*):
    return GgProfiles.get_third_parties()
end

############
#  EXTERNAL 
############

@external
func add_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):  
    assert_only_operator()
    GgProfiles.add_operator(operator)
    return ()
end

@external
func remove_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):  
    assert_only_operator()
    GgProfiles.remove_operator(operator)
    return ()
end

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_data : UpdatableByUserData
):
    assert_only_operator()
    GgProfiles.mint(user_data)
    return ()
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
):     
    assert_only_operator()
    GgProfiles.burn(user_address)
    return ()
end

@external
func update{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_data : UpdatableByUserData
):
    GgProfiles.update(user_data)
    return ()
end

@external
func increase_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, amount : felt
):
    assert_only_operator()
    GgProfiles.increase_reputation(user_address, amount)
    return ()
end

@external
func decrease_reputation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, amount : felt
):
    assert_only_operator()
    GgProfiles.decrease_reputation(user_address, amount)
    return ()
end

@external 
func add_third_party{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    third_party_name : felt
):
    assert_only_operator()
    GgProfiles.add_third_party(third_party_name)
    return ()
end

#todo
@external
func link_third_party_to_profile{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    profile_address : felt, third_party_id : felt, third_party_user_id : felt 
):
    assert_only_operator()
    GgProfiles.link_third_party_to_profile(profile_address, third_party_id, third_party_user_id)
    return ()
end

#todo
@external
func unlink_third_party_to_profile{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    profile_address : felt, third_party_id : felt
):
    assert_only_operator()
    GgProfiles.unlink_third_party_to_profile(profile_address, third_party_id)
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
        assert is_op = TRUE
    end
    return ()
end