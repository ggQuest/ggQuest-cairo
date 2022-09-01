%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

@storage_var
func ReentrancyGuard_Entered() -> (res : felt):
end
namespace ReentrancyGuard:
   func _start{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
        let (has_entered) = ReentrancyGuard_Entered.read()
        with_attr error_message("ReentrancyGuard: reentrant call"):
            assert has_entered = FALSE
        end
        ReentrancyGuard_Entered.write(TRUE)
        return ()
    end

    func _end{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
        ReentrancyGuard_Entered.write(FALSE)
        return ()
    end
end