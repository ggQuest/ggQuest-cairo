%lang starknet

from starware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

############
# STORAGE
############

@storage_var
func operators(address : felt) -> (is_operator : felt):
end

#ggProfiles private profiles;
#ggQuest[] private quests;


# Players' profiles
@storage_var
func profiles() -> (gg_profiles : felt):
end


@storage_var
func completed_quests(completed_quests : felt) -> (number : felt):
end

# questID => number of profiles who completed the quest
@storage_var
func completed_quests_by_profile(profile : felt) -> (quest_ids : felt*, len : felt):
end

# array of game name
@storage_var
func games(game_id: felt) -> (game_name : felt):
end

@storage_var
func thirdParties(index:felt) -> (res : felt):
end


@storage_var
func quests() -> (gg_quest : felt*, len : felt):
end

@storage_var 
func quests_metadata_base_URI() -> (res : felt):
end

# Base URI to get game metadata
@storage_var
func games_metadata_base_URI() -> (res : felt):
end

@storage_var 
func game_id_to_quest_ids(game_id : felt) -> (quest_ids : felt*, len : felt):
end

@storage_var
func quest_id_to_game_id(quest_id : felt) -> (game_id : felt):
end


############
# CONSTRUCTOR
############
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
    _ggProfiles : felt, _questsMetadataBaseURI : felt, _gamesMetadataBaseURI : felt
):
    let (caller_address) = get_caller_address()
    profiles.write(_ggProfiles)
    gamesMetadataBaseURI.write(_gamesMetadataBaseURI)
    questsMetadatBaseURI.write(_questsMetadataBaseURI)
    operators.write(caller_address, true)
    return ()
end

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


#   Add operator      @param _operator : address of the new operator
@external
func add_operator(operator : felt):
    operators.write(operator, true)
    operator_added.emit(operator=operator)
    return ()
end

@external
func remove_operator(operator: felt):
    operators.write(operator, false)
    operator_removed.emit(operator)
    return ()

end

@external
func create_quest(reputation_reward :felt, game_id : felt) -> (res: felt):
    alloc_locals
    # uint questId = quests.length;
    # ggQuest newQuest = new ggQuest(string(abi.encodePacked(questsMetadataBaseURI, Strings.toString(questId))), _reputationReward, profiles);
    # quests.push(newQuest);

    quest_id_to_game_id.write(quest_id, game_id)
    
    # todo : gameIdToQuestIds[_gameId].push(questId);
    let (local quest_ids : felt*) = game_id_to_quest_ids.read(game_id)

    
    # update after pushing quest_id to quest_ids
    game_id_to_quest_ids.write(game_id, quest_ids)

    # todo : profiles.addOperator(address(newQuest));

    let (game_name) = games.read(game_id)
    quest_created.emit(quest_id, game_name)

    return (res=quest_id)

end

@view
func get_quest_URI(quest_id : felt) -> (res: felt):
    let (item) = quests.read(quest_id)
    let (res) = ggQuest(item).get_quest_URI()


    return (res=res)

end

@view 
func get_quests()->(res: felt*):
#todo
end

@external
func add_quest_operator(quest_id : felt, address : felt):
    #todo

    return ()

end

@external
func remove_quest_operator(quest_id : felt, address : felt):
    #todo
    return ()

end

@external
func add_game(game_name:felt)->(res:felt):
    let (size) = 
    game_added.emit(game_name, )
    return size
end

@view
func get_games()->(res: felt*):
# todo
end

@view
func get_url_metadata(game_id: felt)->(res: felt):
# todo
    let (games_metadata) = games_metadata_base_URI.read()
    let (res) = games_metadata + game_id
    return (res)
end