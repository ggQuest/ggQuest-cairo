%lang starknet

from starware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address
)

from contracts.interfaces.IggProfiles import IggProfiles
from contracts.interfaces.IggQuest import IggQuest


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
# EVENTS
############

@event
func operator_added(operator : felt):
end

@event
func remove_operator(operator : felt):
end

@event 
func quest_created(quest_id: felt, game_name: felt):
end

@event
func game_added(game_name: felt, game_id: felt):
end

############
# STORAGE
############

@storage_var
func operators(address : felt) -> (is_operator : felt):
end

# Players' profiles (ggProfiles address contract)
@storage_var
func profiles() -> (res : felt):
end

# ggQuest' contract address
@storage_var
func gg_quest_contract() -> (res : felt):
end


@storage_var
func completed_quests(completed_quests : felt) -> (number : felt):
end

# questID => number of profiles who completed the quest
# todo
@storage_var
func completed_quests_by_profile(profile : felt) -> (quest_ids : felt*, len : felt):
end

# array of game name
@storage_var
func games(game_id : felt) -> (game_name : felt):
end

@storage_var
func games_len() -> (len : felt):
end

@storage_var
func quests(index : felt) -> (contract : felt):
end

@storage_var
func quests_len() -> (len : felt):
end

@storage_var 
func quests_metadata_base_URI() -> (res : felt):
end

# Base URI to get game metadata
@storage_var
func games_metadata_base_URI() -> (res : felt):
end

#todo
@storage_var 
func game_id_to_quest_ids(game_id : felt) -> (quest_ids : felt*, len : felt):
end

@storage_var
func quest_id_to_game_id(quest_id : felt) -> (game_id : felt):
end

############
#  VIEW 
############

@view
func get_ggQuest_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):
    let (contract) = gg_quest_contract.read()
    return (res=contract)
end
@view
func get_ggProfile_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
)-> (res : felt):
    let (contract) = profiles.read()
    return (res=contract)
end

@view
func get_quests{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (quests_len : felt, quests : felt*):
    alloc_locals
    let (quests_len) = quests_len.read()
    let (local quests_array : felt*) = alloc()
    let start = Uint256(0,0)
    let stop = quests_len
    local index_start = 0
    # to add a check if its zero

    _get_quests{quests_array=quests_array, index_start=index_start, stop=stop}(start)
    return (quests_len=quests_len, quests=quests_array)
end

@view
func get_games{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (games_len : felt, games : felt*):
    alloc_locals
    let (games_len) = games_len.read()
    let (local games_array : felt*) = alloc()
    let start = Uint256(0,0)
    let stop = games_len
    local index_start = 0
    # to add a check if its zero

    _get_games{games_array=games_array, index_start=index_start, stop=stop}(start)
    return (games_len=games_len, games=games_array)
end

@view
func get_quests_metadata_base_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (res : felt):
    let (res) = quests_metadata_base_URI.read()
    return (res)
end

@view
func get_games_metadata_base_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (res : felt):
    let (res) = games_metadata_base_URI.read()
    return (res)
end

@view
func get_quest_id_to_game_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    quest_id : felt
) -> (game_id : felt):
    let (game_id) = quest_id_to_game_id.read(quest_id)
    return (game_id)
end

@view
func get_operators{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
) -> (is_operator : felt):
    let (is_operator) = operators.read(address)
    return (is_operator)
end

@view
func get_quest_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    quest_id : felt
) -> (res : felt):
    let (quests_len) = quests_len.read()
    with_attr error_message("QuestID does not exist"):
        assert quests_len > quest_id
    end
    let (quest) = quests_read(quest_id)
    let (gg_quest_address) = gg_quest_contract.read()
    let (res) = IggQuest.get_quest_URI(contract_address=gg_quest_address)

    return (res=res)
end

@view
func get_url_metadata{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    game_id : felt
)->(res : felt):
# todo
    let (games_metadata) = games_metadata_base_URI.read()
    let (res) = games_metadata + game_id
    return (res)
end

############
# CONSTRUCTOR
############
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
    gg_profiles_contract : felt, questsMetadataBaseURI : felt, gamesMetadataBaseURI : felt
):
    let (caller_address) = get_caller_address()
    profiles.write(gg_profiles_contract)
    gamesMetadataBaseURI.write(gamesMetadataBaseURI)
    questsMetadatBaseURI.write(questsMetadataBaseURI)
    operators.write(caller_address, true)
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
    operators.write(operator, true)
    operator_added.emit(operator=operator)
    return ()
end

@external
func remove_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt
):
    operators.write(operator, false)
    operator_removed.emit(operator)
    return ()
end

@external
func create_quest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reputation_reward : felt, game_id : felt
) -> (res : felt):
    alloc_locals
    
    let (quests_len) = quests_len.read()
    # todo : ggQuest newQuest = new ggQuest(string(abi.encodePacked(questsMetadataBaseURI, Strings.toString(questId))), _reputationReward, profiles);
    let (new_quest) = 0
    quests.write(quests_len, new_quest)
    quests_len.write(quests_len + 1)

    quest_id_to_game_id.write(quest_id, game_id)
    
    # todo : gameIdToQuestIds[_gameId].push(questId);

    let (local quest_ids : felt*) = game_id_to_quest_ids.read(game_id)

    
    # update after pushing quest_id to quest_ids
    # game_id_to_quest_ids.write(game_id, quest_ids)
    let (profiles_contract) = profiles.read()
    IggProfiles.add_operator(contract_address=profiles_contract,new_quest)

    let (game_name) = games.read(game_id)
    quest_created.emit(quest_id, game_name)

    return (res=quest_id)

end


@external
func add_quest_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    quest_id : felt, operator : felt
):
    
    let (quests_len) = quests_len.read()
    with_attr error_message("QuestID does not exist"):
        assert quests_len > quest_id
    end
    let (gg_quest_address) = quests_read.read(quest_id)

    IggQuest.add_operator(contract_address=gg_quest_address, operator)
    return ()

end

@external
func remove_quest_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    quest_id : felt, address : felt
):
    let (quests_len) = quests_len.read()
    with_attr error_message("QuestID does not exist"):
        assert quests_len > quest_id
    end
    let (gg_quest_address) = quests_read.read(quest_id)

    IggQuest.remove_operator(contract_address=gg_quest_address, operator)
    return ()

end

# Games & Game studios
@external
func add_game{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    game_name : felt
)->(res : felt):
    let (games_len) = games_len.read()
    games.write(games_len, game_name)
    game_added.emit(game_name, game_len - 1)
    return (res=game_len - 1)
end


############
# INTERNAL
############

func _get_quests{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    quests_array : Reward*,
    index_start : felt,
    stop : felt,
}(start : Uint256):
    let (is_end_of_loop) = uint256_le(stop,start)
    assert_not_zero(is_end_of_loop)

    let (quest : felt) = quests.read(start)
    assert [quests_array + index_start * Uint256.SIZE] = quest
    tempvar index_start = index_start + 1
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    let (next_start, _) = uint256_add(start, Uint256(1,0))
    _get_quests(next_start)
end

func _get_games{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    games_array : Reward*,
    index_start : felt,
    stop : felt,
}(start : Uint256):
    let (is_end_of_loop) = uint256_le(stop,start)
    assert_not_zero(is_end_of_loop)

    let (game : felt) = games.read(start)
    assert [games_array + index_start * Uint256.SIZE] = gamequest
    tempvar index_start = index_start + 1
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    let (next_start, _) = uint256_add(start, Uint256(1,0))
    _get_games(next_start)
end