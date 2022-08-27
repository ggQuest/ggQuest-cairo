%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.token.erc721.library import ERC721
from openzeppelin.introspection.ERC165 import ERC165
from openzeppelin.access.ownable import Ownable

from contracts.tokens.ERC721.ERC721_Metadata_base import (
    ERC721_Metadata_initializer,
    ERC721_Metadata_tokenURI,
    ERC721_Metadata_setBaseTokenURI,
)

