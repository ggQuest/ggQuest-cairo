%lang starknet

from starkware.cairo.common.uint256 import Uint256

from contracts.ggProfiles import UpdatableByUserData

@contract_interface
namespace IggProfiles:

    func add_operator(operator_address : felt):
    end

    func remove_operator(operator_address : felt):
    end

    func mint(user_data : UpdatableByUserData):
    end

    func burn(user_address : felt):
    end

    func update(user_data : UpdatableByUserData):
    end

    func increase_reputation(user_address : felt, amount : Uint256):
    end

    func decrease_reputation(user_address : felt, amount : Uint256):
    end

    func add_third_party(third_party_name : felt):
    end

    func link_third_party_to_profile(profile_address : felt, third_party_id : felt, third_party_user_id : felt):
    end

    func unlink_third_party_to_profile(profile_address : felt, third_party_id : felt):
    end

end