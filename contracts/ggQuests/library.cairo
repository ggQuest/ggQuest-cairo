%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address
)

from starkware.cairo.common.math import (
    assert_not_zero,
    assert_nn_le,
    assert_not_equal,
    assert_le,
    assert_lt
)

from starkware.cairo.common.uint256 import Uint256

from contracts.interfaces.IggProfiles import IggProfiles
from contracts.interfaces.IggQuest import IggQuest

############
# EVENTS
############

@event
func OperatorAdded(operator : felt):
end

@event
func RemoveOperator(operator : felt):
end

@event 
func QuestCreated(quest_id: felt, game_name: felt):
end

@event
func GameAdded(game_name: felt, game_id: felt):
end

############
# STORAGE
############

@storage_var
func Operators(address : felt) -> (is_operator : felt):
end

# Players' Profiles (ggProfiles address contract)
@storage_var
func Profiles() -> (res : felt):
end

# ggQuest' contract address
@storage_var
func Gg_Quest_Contract() -> (res : felt):
end


@storage_var
func Completed_Quests(completed_quests : felt) -> (number : felt):
end

# questID => number of Profiles who completed the quest
@storage_var
func Completed_Quests_By_Profile(profile : felt, index : felt) -> (quest_id : felt):
end

@storage_var
func Completed_Quests_By_Profile_Len(profile : felt) -> (len : felt):
end

# array of game name
@storage_var
func Games(game_id : felt) -> (game_name : felt):
end

@storage_var
func Games_len() -> (len : felt):
end

@storage_var
func Quests(index : felt) -> (contract : felt):
end

@storage_var
func Quests_Len() -> (len : felt):
end

@storage_var 
func Quests_Metadata_Base_URI() -> (res : felt):
end

# Base URI to get game metadata
@storage_var
func Games_Metadata_Base_URI() -> (res : felt):
end


@storage_var 
func Game_Id_To_Quest_Ids(game_id : felt, index : felt) -> (quest_id : felt):
end

@storage_var
func Game_Id_To_Quest_Ids_Len(game_id : felt) -> (len : felt):
end


@storage_var
func Quest_Id_To_Game_Id(quest_id : felt) -> (game_id : felt):
end

namespace GgQuests:

    
    func get_ggQuest_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    )-> (res : felt):
        let (contract) = Gg_Quest_Contract.read()
        return (res=contract)
    end
    
    func get_ggProfile_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    )-> (res : felt):
        let (contract) = Profiles.read()
        return (res=contract)
    end

    
    func get_quests{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (quests_len : felt, quests : felt*):
        alloc_locals
        let (quests_len) = Quests_Len.read()
        let (local quests_array : felt*) = alloc()
        local start = 0
        let stop = quests_len

        get_quests_loop{quests_array=quests_array, stop=stop}(start)
        return (quests_len=quests_len, quests=quests_array)
    end

    
    func get_games{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (games_len : felt, games : felt*):
        alloc_locals
        let (games_len) = Games_Len.read()
        let (local games_array : felt*) = alloc()
        local start = 0
        let stop = games_len
        # to add a check if its zero

        get_games_loop{games_array=games_array, index_start=index_start, stop=stop}(start)
        return (games_len=games_len, games=games_array)
    end

    
    func get_quests_metadata_base_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (res : felt):
        let (res) = Quests_Metadata_Base_URI.read()
        return (res)
    end

    
    func get_games_metadata_base_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (res : felt):
        let (res) = Games_Metadata_Base_URI.read()
        return (res)
    end

    
    func get_quest_id_to_game_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        quest_id : felt
    ) -> (game_id : felt):
        let (game_id) = Quest_Id_To_Game_Id.read(quest_id)
        return (game_id)
    end

    
    func get_operators{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        address : felt
    ) -> (is_operator : felt):
        let (is_operator) = Operators.read(address)
        return (is_operator)
    end

    
    func get_quest_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        quest_id : felt
    ) -> (res : felt):
        let (quests_len) = Quests_Len.read()
        with_attr error_message("QuestID does not exist"):
            assert_lt(quest_id, quests_len)
        end
        let (quest) = Quests.read(quest_id)
        let (gg_quest_address) = Gg_Quest_Contract.read()
        let (res) = IggQuest.get_quest_URI(contract_address=gg_quest_address)

        return (res=res)
    end

    
    func get_url_metadata{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        game_id : felt
    )->(res : felt):
    # todo
        let (games_metadata) = Games_Metadata_Base_URI.read()
        return (res=games_metadata + game_id)
    end

     
    func get_game_id_to_quest_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        game_id : felt
    ) -> (quest_ids_len : felt, quest_ids : felt*):
        alloc_locals
        local start = 0
        let (stop) = Game_Id_To_Quest_Ids_Len.read(game_id)
        let (local array : felt*) = alloc()
        get_game_id_to_quest_id_loop{array=array, game_id=game_id, stop=stop}(start)
        return (quest_ids_len=stop, quest_ids=array)
    end


    
    func add_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        operator : felt
    ):
        Operators.write(operator, true)
        OperatorAdded.emit(operator=operator)
        return ()
    end

    
    func remove_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        operator : felt
    ):
        Operators.write(operator, false)
        OperatorRemoved.emit(operator)
        return ()
    end

    
    func create_quest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        reputation_reward : felt, game_id : felt
    ) -> (res : felt):
        alloc_locals
        let (quests_len) = Quests_Len.read()
        let quest_id = quests_len
        # todo : ggQuest newQuest = new ggQuest(string(abi.encodePacked(questsMetadataBaseURI, Strings.toString(questId))), _reputationReward, Profiles);
        let new_quest = 0
        Quests.write(quests_len, new_quest)
        Quests_Len.write(quests_len + 1)

        Quest_Id_To_Game_Id.write(quest_id, game_id)
        let (index) = Game_Id_To_Quest_Ids_Len.read(game_id)
        Game_Id_To_Quest_Ids.write(game_id, index, quest_id)
        Game_Id_To_Quest_Ids_Len.write(game_id, index + 1)

        # update after pushing quest_id to quest_ids
        let (profiles_contract) = Profiles.read()
        IggProfiles.add_operator(contract_address=profiles_contract, new_quest)

        let (game_name) = Games.read(game_id)
        QuestCreated.emit(quest_id, game_name)

        return (res=quest_id)

    end


    
    func add_quest_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        quest_id : felt, operator : felt
    ):
        let (quests_len) = Quests_Len.read()
        with_attr error_message("QuestID does not exist"):
            assert_lt(quest_id, quests_len)
        end
        let (gg_quest_address) = Quests.read(quest_id)

        IggQuest.add_operator(contract_address=gg_quest_address, operator)
        return ()

    end

    
    func remove_quest_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        quest_id : felt, address : felt
    ):
        let (quests_len) = Quests_Len.read()
        with_attr error_message("QuestID does not exist"):
            assert_lt(quest_id, quests_len)
        end
        let (gg_quest_address) = Quests.read(quest_id)

        IggQuest.remove_operator(contract_address=gg_quest_address, operator)
        return ()

    end

    # Games & Game studios
    
    func add_game{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        game_name : felt
    )->(res : felt):
        let (games_len) = Games_Len.read()
        Games.write(games_len, game_name)
        GameAdded.emit(game_name, game_len - 1)
        return (res=game_len - 1)
    end
end


############
# INTERNAL
############

func get_quests_loop{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    quests_array : felt*,
    stop : felt,
}(start : felt):
    if start == stop:
        return ()
    end

    let (quest : felt) = Quests.read(start)
    assert [quests_array + start] = quest
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    return get_quests_loop(start + 1)
end

func get_games_loop{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    games_array : felt*,
    stop : felt,
}(start : felt):
    if start == stop:
        return ()
    end

    let (game : felt) = Games.read(start)
    assert [games_array + start] = game
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    return get_games_loop(start + 1)
end

func get_game_id_to_quest_id_loop{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    array : felt*,
    game_id : felt,
    stop : felt,
}(start : felt):
    if start == stop:
        return ()
    end
    let (quest_id) = Game_Id_To_Quest_Id.read(game_id, start)
    assert [array + start] = quest_id
    return get_game_id_to_quest_id_loop(start + 1)
end