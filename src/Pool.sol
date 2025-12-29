// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract Pool is ERC20 {
    using SafeERC20 for IERC20;

    uint256 constant MAX_SUPPLY = 1e9 ether;

    address constant ISSUER = 0xEbCaD83FeAD16e7D18DD691fFD2b39eca56677d8;

    string public constant ONE_NAME = "Uniteum 1";

    string public constant ONE_SYMBOL = "1";

    string public constant NAME_SUFFIX = " per 1";

    string public constant SYMBOL_SUFFIX = "/1";

    Pool public immutable ONE = this;

    IERC20Metadata public underlying = IERC20Metadata(address(0xdeadbeef));

    function name() public view virtual override returns (string memory name_) {
        if (this == ONE) {
            return ONE_NAME;
        } else {
            return string.concat(underlying.name(), NAME_SUFFIX);
        }
    }

    function symbol() public view virtual override returns (string memory) {
        if (this == ONE) {
            return ONE_SYMBOL;
        } else {
            return string.concat(underlying.symbol(), SYMBOL_SUFFIX);
        }
    }

    function balances() public view returns (uint256 bu, uint256 b1) {
        bu = balanceOf(address(this));
        b1 = ONE.balanceOf(address(this));
    }

    function buyQuote(uint256 bu, uint256 b1, uint256 du) public pure returns (uint256 d1) {
        if (bu <= du) {
            revert InsufficientLiquidity();
        }
        uint256 k = bu * b1;
        uint256 nu = bu - du;
        uint256 n1 = k / nu;
        d1 = b1 - n1;
    }

    function sellQuote(uint256 bu, uint256 b1, uint256 du) public pure returns (uint256 d1) {
        uint256 k = bu * b1;
        uint256 nu = bu + du;
        uint256 n1 = k / nu;
        d1 = n1 - b1;
    }

    function buyQuote(uint256 du) public view returns (uint256 bu, uint256 b1, uint256 d1) {
        (bu, b1) = balances();
        d1 = buyQuote(bu, b1, du);
    }

    function buyWithQuote(uint256 d1) public view returns (uint256 bu, uint256 b1, uint256 du) {
        (bu, b1) = balances();
        du = sellQuote(b1, bu, d1);
    }

    function buy(uint256 du) external returns (uint256 bu, uint256 b1, uint256 d1) {
        (bu, b1, d1) = buyQuote(du);
        buyTransfers(du, d1);
    }

    function buyWith(uint256 d1) external returns (uint256 bu, uint256 b1, uint256 du) {
        (bu, b1, du) = buyWithQuote(d1);
        buyTransfers(du, d1);
    }

    function sellQuote(uint256 du) public view returns (uint256 bu, uint256 b1, uint256 d1) {
        (bu, b1) = balances();
        d1 = sellQuote(bu, b1, du);
    }

    function sellForQuote(uint256 d1) public view returns (uint256 bu, uint256 b1, uint256 du) {
        (bu, b1) = balances();
        d1 = buyQuote(b1, bu, du);
    }

    function sell(uint256 du) external returns (uint256 bu, uint256 b1, uint256 d1) {
        (bu, b1, d1) = sellQuote(du);
        sellTransfers(du, d1);
    }

    function sellFor(uint256 d1) external returns (uint256 bu, uint256 b1, uint256 du) {
        (bu, b1, du) = sellForQuote(d1);
        sellTransfers(du, d1);
    }

    function buyTransfers(uint256 du, uint256 d1) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(ONE).transfer(address(this), d1);
        _transfer(address(this), msg.sender, du);
    }

    function sellTransfers(uint256 du, uint256 d1) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(ONE).transferFrom(address(this), msg.sender, d1);
        _transfer(msg.sender, address(this), du);
    }

    function burn(uint256 units) external returns (uint256 out) {
        uint256 u1 = balanceOf(address(this));
        uint256 u2 = totalSupply() - u1;
        out = units * u1 / u2;
        _burn(msg.sender, units);
        IERC20(underlying).safeTransfer(msg.sender, out);
    }

    function mint(uint256 units) external {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), units);
        _mint(msg.sender, units);
        _mint(address(this), units);
    }

    constructor() ERC20("", "") {
        _mint(ISSUER, MAX_SUPPLY);
    }

    function __predict(IERC20Metadata underlying_) public view returns (address predicted, bytes32 newSalt) {
        newSalt = bytes32(uint256(uint160(address(underlying_))));
        predicted = Clones.predictDeterministicAddress(address(ONE), newSalt, address(ONE));
    }

    function __clone(IERC20Metadata underlying_) public returns (address instance) {
        if (this == ONE) {
            bytes32 newSalt;
            (instance, newSalt) = __predict(underlying_);

            if (instance.code.length == 0) {
                instance = Clones.cloneDeterministic(address(ONE), newSalt);
                Pool(instance).__initialize(underlying_);
            }
        } else {
            instance = ONE.__clone(underlying_);
        }
    }

    function __initialize(IERC20Metadata underlying_) public {
        if (address(underlying_) == address(0)) {
            underlying = underlying_;
        }
    }

    error InsufficientLiquidity();
}
