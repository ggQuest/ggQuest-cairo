%lang starknet

from contracts.ggQuest.library import Reward

from starkware.cairo.common.uint256 import (
    Uint256
)

@contract_interface
namespace IggQuest: 

    func add_operator(operator : felt):
    end

    func remove_operator(operator : felt):
    end

    func add_reward(reward : Reward) -> (res : Uint256):
    end

    func send_reward(player : felt):
    end

    func increase_reward_amount(amount : Uint256, reward : Reward):
    end

    func update_reputation_reward(new_value : felt):
    end

    func activate_quest(withdrawal_address : felt):
    end

    func deactivate_quest(withdrawal_address : felt):
    end
    
    func get_quest_URI() -> (res : felt):
    end
    
end