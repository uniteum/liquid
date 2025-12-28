// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title IUnit — A universal liquidity system based on symbolic units.
 * See {IUnit} for details.
 */
contract Pool is ERC20 {
    using SafeERC20 for IERC20;

    /**
     * @notice Total minted supply: 1 billion tokens with 18 decimals.
     */
    uint256 constant MAX_SUPPLY = 1e9 ether;

    /**
     * @notice Contract receiving all initial supply.
     */
    address constant ISSUER = 0xEbCaD83FeAD16e7D18DD691fFD2b39eca56677d8;

    error InsufficientLiquidity();

    /// @notice The ERC-20 symbol for the central 1 token.
    string public constant ONE_NAME = "Uniteum 1";

    /// @notice The ERC-20 symbol for the central 1 token.
    string public constant ONE_SYMBOL = "1";

    /// @notice The ERC-20 symbol for the central 1 token.
    string public constant NAME_SUFFIX = " per 1";

    /// @notice The ERC-20 symbol for the central 1 token.
    string public constant SYMBOL_SUFFIX = "/1";

    /// @notice The central 1 unit.
    Pool public immutable ONE = this;

    IERC20Metadata public underlying;

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

    function buyQuote(uint256 du) public view returns (uint256 dv) {
        uint256 u = balanceOf(address(this));
        if (u <= du) {
            revert InsufficientLiquidity();
        }
        uint256 v = ONE.balanceOf(address(this));
        uint256 k = u * v;
        uint256 newU = u - du;
        uint256 newV = k / newU;
        dv = v - newV;
    }

    function sellQuote(uint256 du) public view returns (uint256 dv) {
        uint256 u = balanceOf(address(this));
        uint256 v = ONE.balanceOf(address(this));
        uint256 k = u * v;
        uint256 newU = u + du;
        uint256 newV = k / newU;
        dv = newV - v;
    }

    function buy(uint256 du) external returns (uint256 dv) {
        dv = buyQuote(du);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(ONE).transfer(address(this), dv);
        _transfer(address(this), msg.sender, dv);
    }

    function sell(uint256 du) external returns (uint256 dv) {
        dv = sellQuote(du);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(ONE).transferFrom(address(this), msg.sender, dv);
        _transfer(msg.sender, address(this), dv);
    }

    /**
     * @notice Burn units of the holder.
     * @dev - Only Units with the same 1 can call this function.
     * @param units The number of units to burn.
     */
    function burn(uint256 units) external returns (uint256 out) {
        uint256 u1 = balanceOf(address(this));
        uint256 u2 = totalSupply() - u1;
        out = units * u1 / u2;
        _burn(msg.sender, units);
        IERC20(underlying).safeTransfer(msg.sender, out);
    }

    /**
     * @notice Mint units for the holder.
     * @param units The number of units to mint.
     */
    function mint(uint256 units) external {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), units);
        _mint(msg.sender, units);
        _mint(address(this), units);
    }

    /**
     * @notice Deploys primordial "1" and mints MAX_SUPPLY to ISSUER.
     * @dev No further minting possible.
     */
    constructor() ERC20("", "") {
        _mint(ISSUER, MAX_SUPPLY);
        underlying = this; // Prevent setting.
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
}
