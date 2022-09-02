%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE

from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address
)
from starkware.cairo.common.math import (
    assert_not_zero,
)
from contracts.ggQuests.library import (
    GgQuests,
    Operators,
    Profiles,
    Games_Metadata_Base_URI,
    Quests_Metadata_Base_URI
)

############
#  VIEW 
############

@view
func get_ggQuest_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):   
    return GgQuests.get_ggQuest_address()
end
@view
func get_ggProfile_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):
    return GgQuests.get_ggProfile_address()
end 

@view
func get_quests{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (quests_len : felt, quests : felt*):
    let (quests_len, quests) = GgQuests.get_quests()
    return (quests_len, quests)
end

@view
func get_games{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (games_len : felt, games : felt*):
    let (games_len, games) = GgQuests.get_games()
    return (games_len, games)
end

@view
func get_quests_metadata_base_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (res : felt):
    return GgQuests.get_quests_metadata_base_URI()
end

@view
func get_games_metadata_base_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (res : felt):
    return GgQuests.get_games_metadata_base_URI()

end

@view
func get_quest_id_to_game_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    quest_id : felt
) -> (game_id : felt):
    return GgQuests.get_quest_id_to_game_id(quest_id)
end

@view
func get_operators{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
) -> (is_operator : felt):
    return GgQuests.get_operators(address)
end

@view
func get_quest_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    quest_id : felt
) -> (res : felt):
    return GgQuests.get_quest_URI(quest_id)
end

@view
func get_url_metadata{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    game_id : felt
)->(res : felt):
    return GgQuests.get_url_metadata(game_id)
end

@view 
func get_game_id_to_quest_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    game_id : felt
) -> (quest_ids_len : felt, quest_ids : felt*):
    let (quest_ids_len, quest_ids) = GgQuests.get_game_id_to_quest_id(game_id)
    return (quest_ids_len, quest_ids)
end

############
# CONSTRUCTOR
############
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
    gg_profiles_contract : felt, questsMetadataBaseURI : felt, gamesMetadataBaseURI : felt
):
    let (caller_address) = get_caller_address()
    Profiles.write(gg_profiles_contract)
    Games_Metadata_Base_URI.write(gamesMetadataBaseURI)
    Quests_Metadata_Base_URI.write(questsMetadataBaseURI)
    Operators.write(caller_address, TRUE)
    return ()
end


############
# EXTERNAL
############
#   Add operator @param _operator : address of the new operator
@external
func add_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):
    assert_only_operator()
    GgQuests.add_operator(operator)
    return ()
end

@external
func remove_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):
    assert_only_operator()
    GgQuests.remove_operator(operator)
    return ()
end

@external
func create_quest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reputation_reward : felt, game_id : felt
) -> (res : felt):
    assert_only_operator()
    return create_quest(reputation_reward, game_id)
end


@external
func add_quest_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    quest_id : felt, operator : felt
):
    assert_only_operator()
    GgQuests.add_quest_operator(quest_id, operator)
    return ()
end

@external
func remove_quest_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    quest_id : felt, operator : felt
):
    assert_only_operator()
    GgQuests.remove_quest_operator(quest_id, operator)
    return ()
end

# Games & Game studios
@external
func add_game{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    game_name : felt
)->(res : felt):
    assert_only_operator()
    return GgQuests.add_game(game_name)
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
        assert is_op = 1
    end
    return ()
end