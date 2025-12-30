// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract Liquid is ERC20, ReentrancyGuardTransient {
    using SafeERC20 for IERC20Metadata;

    uint256 public constant ONE_SUPPLY = 1e9 ether;
    string public constant ONE_NAME = "Liquid 1";
    string public constant ONE_SYMBOL = "1";
    string public constant NAME_SUFFIX = " per 1";
    string public constant SYMBOL_SUFFIX = "/1";

    Liquid public immutable ONE = this;
    address public immutable ISSUER = 0xEbCaD83FeAD16e7D18DD691fFD2b39eca56677d8;

    IERC20Metadata public substance = IERC20Metadata(address(0xdeadbeef));

    function mint(uint256 units) external nonReentrant {
        substance.safeTransferFrom(msg.sender, address(this), units);
        _mint(address(this), units);
        _mint(msg.sender, units);
        emit Minted(msg.sender, this, units);
    }

    function burn(uint256 units) external nonReentrant returns (uint256 ash) {
        uint256 total = totalSupply();
        uint256 wet = balanceOf(address(this));
        uint256 dry = total - wet;
        uint256 myWet = 2 * units * wet / total;
        uint256 myDry = 2 * units * dry / total;
        ash = units * substance.balanceOf(address(this)) / dry;
        _burn(address(this), myWet);
        _burn(msg.sender, myDry);
        substance.safeTransfer(msg.sender, ash);
        emit Burned(msg.sender, this, units, ash);
    }

    function balances() public view returns (uint256 wet, uint256 ones) {
        wet = balanceOf(address(this));
        ones = ONE.balanceOf(address(this));
    }

    function buyQuote(uint256 wet, uint256 ones, uint256 units) public pure returns (uint256 myOnes) {
        if (wet <= units) {
            revert Thirst();
        }
        uint256 area = wet * ones;
        uint256 newWet = wet - units;
        uint256 newOnes = area / newWet;
        myOnes = ones - newOnes;
    }

    function sellQuote(uint256 wet, uint256 ones, uint256 units) public pure returns (uint256 myOnes) {
        uint256 area = wet * ones;
        uint256 newWet = wet + units;
        uint256 newOnes = area / newWet;
        myOnes = newOnes - ones;
    }

    function buyQuote(uint256 units) public view returns (uint256 wet, uint256 ones, uint256 myOnes) {
        (wet, ones) = balances();
        myOnes = buyQuote(wet, ones, units);
    }

    function buyWithQuote(uint256 myOnes) public view returns (uint256 wet, uint256 ones, uint256 units) {
        (wet, ones) = balances();
        units = sellQuote(ones, wet, myOnes);
    }

    function buy(uint256 units) external returns (uint256 wet, uint256 ones, uint256 myOnes) {
        (wet, ones, myOnes) = buyQuote(units);
        buyTransfers(units, myOnes);
    }

    function buyWith(uint256 myOnes) external returns (uint256 wet, uint256 ones, uint256 units) {
        (wet, ones, units) = buyWithQuote(myOnes);
        buyTransfers(units, myOnes);
    }

    function sellQuote(uint256 units) public view returns (uint256 wet, uint256 ones, uint256 myOnes) {
        (wet, ones) = balances();
        myOnes = sellQuote(wet, ones, units);
    }

    function sellForQuote(uint256 myOnes) public view returns (uint256 wet, uint256 ones, uint256 units) {
        (wet, ones) = balances();
        myOnes = buyQuote(ones, wet, units);
    }

    function sell(uint256 units) external returns (uint256 wet, uint256 ones, uint256 myOnes) {
        (wet, ones, myOnes) = sellQuote(units);
        sellTransfers(units, myOnes);
    }

    function sellFor(uint256 myOnes) external returns (uint256 wet, uint256 ones, uint256 units) {
        (wet, ones, units) = sellForQuote(myOnes);
        sellTransfers(units, myOnes);
    }

    function buyTransfers(uint256 units, uint256 myOnes) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(ONE).transfer(address(this), myOnes);
        _transfer(address(this), msg.sender, units);
        emit Bought(msg.sender, this, units, myOnes);
    }

    function sellTransfers(uint256 units, uint256 myOnes) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(ONE).transferFrom(address(this), msg.sender, myOnes);
        _transfer(msg.sender, address(this), units);
        emit Sold(msg.sender, this, units, myOnes);
    }

    function name() public view virtual override returns (string memory) {
        return this == ONE ? ONE_NAME : string.concat(substance.name(), NAME_SUFFIX);
    }

    function symbol() public view virtual override returns (string memory) {
        return this == ONE ? ONE_SYMBOL : string.concat(substance.symbol(), SYMBOL_SUFFIX);
    }

    function predict(IERC20Metadata stuff) public view returns (address predicted, bytes32 salt) {
        if (address(stuff) == address(0)) {
            revert Nothing();
        }
        salt = bytes32(uint256(uint160(address(stuff))));
        predicted = Clones.predictDeterministicAddress(address(ONE), salt, address(ONE));
    }

    function clone(IERC20Metadata stuff) public returns (Liquid liquid) {
        if (this == ONE) {
            bytes32 salt;
            address instance;
            (instance, salt) = predict(stuff);
            liquid = Liquid(instance);

            if (instance.code.length == 0) {
                instance = Clones.cloneDeterministic(address(ONE), salt);
                Liquid(instance).__initialize(stuff);
                emit Cloned(instance, stuff);
            }
        } else {
            liquid = ONE.clone(stuff);
        }
    }

    function __initialize(IERC20Metadata stuff) public {
        if (address(substance) == address(0)) {
            substance = stuff;
        }
    }

    constructor() ERC20("", "") {
        _mint(ISSUER, ONE_SUPPLY);
    }

    event Minted(address indexed minter, Liquid indexed token, uint256 units);
    event Burned(address indexed burner, Liquid indexed token, uint256 units, uint256 ash);
    event Bought(address indexed buyer, Liquid indexed token, uint256 units, uint256 ones);
    event Sold(address indexed seller, Liquid indexed token, uint256 units, uint256 ones);
    event Cloned(address indexed clone, IERC20Metadata indexed substance);

    error Nothing();
    error Thirst();
}
