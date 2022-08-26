%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_sub,
    uint256_le,
    uint256_lt,
    uint256_check,
)

### Storage

@storage_var
func ERC20_name_() -> (name: felt):
end

@storage_var
func ERC20_symbol_() -> (symbol : felt):
end

@storage_var
func ERC20_decimals_() -> (decimals: felt):
end

@storage_var
func ERC20_total_supply() -> (total_supply : Uint256):
end

@storage_var
func ERC20_balances(account : felt) -> (balance: Uint256):
end

@storage_var
func ERC20_allowances(owner: felt, spender: felt) -> (allowance: Uint256):
end

## Constructor

func ERC20_initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    name: felt, symbol : felt, initial_supply: Uint256, recipient: felt
):
    ERC20_name_.write(name)
    ERC20_symbol_.write(symbol)
    ERC20_decimals_.write(18)
    ERC20_mint(recipient, initial_supply)
    return ()
end


func ERC20_name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (name : felt):  
    let (name) = ERC20_name_.read()
    return (name)
end

func ERC20_symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
)-> (symbol : felt):
    let (symbol) = ERC20_symbol_.read()
    return (symbol)
end

func ERC20_totalSupply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
)-> (supply : Uint256):
    let (supply : Uint256) = ERC20_total_supply.read()
    return (supply)
end

func ERC20_decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
)-> (decimals: felt):
    let (decimals) = ERC20_decimals_.read()
    return (decimals)
end

func ERC20_balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account : felt
) -> (balance : Uint256):
    let (balance : Uint256) = ERC20_balances.read(account)
    return (balance)
end


func ERC20_allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt
)-> (remaining : Uint256):
    let (remaining : Uint256) = ERC20_allowances.read(owner, spender)
    return (remaining)
end

func ERC20_transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient : felt, amount : Uint256
):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)
    return ()
end

func ERC20_transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local caller_allowance : Uint256) = ERC20_allowances.read(owner = sender, spender = caller)

    let (enough_allowance) = uint256_le(amount, caller_allowance)
    assert_not_zero(enough_allowance)

    _transfer(sender, recipient, amount)

    let (new_allowance : Uint256) = uint256_sub(caller_allowance, amount)
    ERC20_allowances.write(sender, caller, new_allowance)

    return ()
end

func ERC20_approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
):
    let (caller) = get_caller_address()
    assert_not_zero(spender)
    assert_not_zero(caller)
    uint256_check(amount)
    ERC20_allowances.write(caller, spender, amount)

    return ()
end

func ERC20_increaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, added_value : Uint256
) :
    alloc_locals
    uint256_check(added_value)
    let (local caller) = get_caller_address()
    let (local current_allowance : Uint256) = ERC20_allowances.read(caller, spender)

    let (local new_allowance: Uint256, is_overflow) = unt256.add(current_allowance, added_value)
    assert (is_overflow) = 0

    ERC20_approve(spender, new_allowance)
    return ()
end

func ERC20_decreaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender : felt, subtracted_value : Uint256
):
    alloc_locals
    let (local caller) = get_caller_address()
    let(local current_allowance : Uint256) = ERC20_allowances.read(caller,spender)

    let (local new_allowance : Uint256) = uint256_sub(current_allowance, subtracted_value)
    let (enough_allowance) = uitn256_lt(new_allowance, current_allowance)
    assert_not_zero(enough_allowance)

    ERC20_approve(spender, new_allowance)

    return ()
end

func ERC20_mint{syscall_ptr : felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount : Uint256
):
    alloc_locals
    assert_not_zero(amount)
    assert_not_zero(recipient)

    let (balance: Uint256) = ERC20_balances.read(account = recipient)
    let (new_balance, _ : Uint256) = uint256.add(balance, amount)
    ERC20_balances.write(recipient, new_balance)

    let (local supply: Uint256) = ERC20_total_supply.read()
    let (local new_supply : Uint256, is_overflow) = uint256.add(supply, amount)
    assert (is_overflow) = 0

    ERC20_total_supply.write(new_supply)
    return ()
end

func ERC20_burn{syscall_ptr : felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account: felt, amount: Uint256
):
    alloc_locals
    assert_not_zero(account)
    assert_not_zero(amount)
    let (current_balance : Uint256) = ERC20_balances.read(account)
    let(enough_balance) = uint256_le(amount, current_balance)
    assert_not_zero(enough_balance)

    let(new_balance : Uint256) = uint256.sub(current_balance, amount)
    ERC20_balances.write(account, new_balance)

    let (local supply : Uint256) = ERC20_total_supply.read()
    let(local new_supply : Uint256) = uitn256_add(supply, amount)
    ERC20_total_supply.write(new_supply)

    return ()

end

# internal

func _transfer{syscall_ptr : felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    sender: felt, recipient: felt, amount: Uint256
):
    alloc_locals
    assert_not_zero(sender)
    assert_not_zero(sender)
    uint256_check(amount)

    let (local sender_balance : Uint256) = ERC20_balances.read(account=sender)

    let (enough_balance) = uint256_le(amount, sender_balance)
    assert_not_zero(enough_balance)

    let (new_sender_balance : Uint256) = uint256(sender_balance, amount)
    ERC20_balances.write(sender, new_sender_balance)

    let (recipient_balance : Uint256) = ERC20_balances.read(account=recipient)

    let (new_recipient_balance : Uint256) = uint256_add(recipient_balance, amount)
    ERC20_balances.write(recipient, new_receipient_balance)

    return ()

end