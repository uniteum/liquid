// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract Liquid is ERC20, ReentrancyGuardTransient {
    using SafeERC20 for IERC20Metadata;

    uint256 public constant ONE_TOTAL = 1e9 ether;
    string public constant ONE_NAME = "Watar";
    string public constant ONE_SYMBOL = "WATAR";

    Liquid public immutable ONE = this;
    address public immutable GOD = 0xEbCaD83FeAD16e7D18DD691fFD2b39eca56677d8;

    IERC20Metadata public solid = IERC20Metadata(address(0xdead));

    function melt(uint256 solids) external nonReentrant {
        solid.safeTransferFrom(msg.sender, address(this), solids);
        _mint(address(this), solids);
        _mint(msg.sender, solids);
        emit Minted(msg.sender, this, solids);
    }

    function freeze(uint256 liquids) external nonReentrant returns (uint256 solids) {
        uint256 total = totalSupply();
        uint256 wet = balanceOf(address(this));
        uint256 dry = total - wet;
        uint256 myWet = 2 * liquids * wet / total;
        uint256 myDry = 2 * liquids * dry / total;
        solids = liquids * solid.balanceOf(address(this)) / dry;
        _burn(address(this), myWet);
        _burn(msg.sender, myDry);
        solid.safeTransfer(msg.sender, solids);
        emit Burned(msg.sender, this, liquids, solids);
    }

    function balances() public view returns (uint256 wet, uint256 lake) {
        wet = balanceOf(address(this));
        lake = ONE.balanceOf(address(this));
    }

    function buyQuote(uint256 wet, uint256 lake, uint256 liquids) public pure returns (uint256 water) {
        if (wet <= liquids) {
            revert Thirst();
        }
        uint256 area = wet * lake;
        uint256 newWet = wet - liquids;
        uint256 newOnes = area / newWet;
        water = lake - newOnes;
    }

    function sellQuote(uint256 wet, uint256 lake, uint256 liquids) public pure returns (uint256 water) {
        uint256 area = wet * lake;
        uint256 newWet = wet + liquids;
        uint256 newOnes = area / newWet;
        water = newOnes - lake;
    }

    function buyQuote(uint256 liquids) public view returns (uint256 wet, uint256 lake, uint256 water) {
        (wet, lake) = balances();
        water = buyQuote(wet, lake, liquids);
    }

    function buyWithQuote(uint256 water) public view returns (uint256 wet, uint256 lake, uint256 liquids) {
        (wet, lake) = balances();
        liquids = sellQuote(lake, wet, water);
    }

    function buy(uint256 liquids) external returns (uint256 wet, uint256 lake, uint256 water) {
        (wet, lake, water) = buyQuote(liquids);
        bought(liquids, water);
    }

    function buyWith(uint256 water) external returns (uint256 wet, uint256 lake, uint256 liquids) {
        (wet, lake, liquids) = buyWithQuote(water);
        bought(liquids, water);
    }

    function sellQuote(uint256 liquids) public view returns (uint256 wet, uint256 lake, uint256 water) {
        (wet, lake) = balances();
        water = sellQuote(wet, lake, liquids);
    }

    function sellForQuote(uint256 water) public view returns (uint256 wet, uint256 lake, uint256 liquids) {
        (wet, lake) = balances();
        water = buyQuote(lake, wet, liquids);
    }

    function sell(uint256 liquids) external returns (uint256 wet, uint256 lake, uint256 water) {
        (wet, lake, water) = sellQuote(liquids);
        sold(liquids, water);
    }

    function sellFor(uint256 water) external returns (uint256 wet, uint256 lake, uint256 liquids) {
        (wet, lake, liquids) = sellForQuote(water);
        sold(liquids, water);
    }

    function bought(uint256 liquids, uint256 water) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(ONE).transfer(address(this), water);
        _transfer(address(this), msg.sender, liquids);
        emit Bought(msg.sender, this, liquids, water);
    }

    function sold(uint256 liquids, uint256 water) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(ONE).transferFrom(address(this), msg.sender, water);
        _transfer(msg.sender, address(this), liquids);
        emit Sold(msg.sender, this, liquids, water);
    }

    function name() public view virtual override returns (string memory) {
        return this == ONE ? ONE_NAME : solid.name();
    }

    function symbol() public view virtual override returns (string memory) {
        return this == ONE ? ONE_SYMBOL : solid.symbol();
    }

    function predict(IERC20Metadata stuff) public view returns (address future, bytes32 salt) {
        if (address(stuff) == address(0)) {
            revert Nothing();
        }
        salt = bytes32(uint256(uint160(address(stuff))));
        future = Clones.predictDeterministicAddress(address(ONE), salt, address(ONE));
    }

    function make(IERC20Metadata stuff) public returns (Liquid liquid) {
        if (this == ONE) {
            bytes32 salt;
            address future;
            (future, salt) = predict(stuff);
            liquid = Liquid(future);

            if (future.code.length == 0) {
                future = Clones.cloneDeterministic(address(ONE), salt);
                liquid.__initialize(stuff);
                emit Made(liquid, stuff);
            }
        } else {
            liquid = ONE.make(stuff);
        }
    }

    function __initialize(IERC20Metadata stuff) public {
        if (address(solid) == address(0)) {
            solid = stuff;
        }
    }

    constructor() ERC20("", "") {
        _mint(GOD, ONE_TOTAL);
    }

    event Minted(address indexed minter, Liquid indexed liquid, uint256 liquids);
    event Burned(address indexed burner, Liquid indexed liquid, uint256 liquids, uint256 solids);
    event Bought(address indexed buyer, Liquid indexed liquid, uint256 liquids, uint256 water);
    event Sold(address indexed seller, Liquid indexed liquid, uint256 liquids, uint256 water);
    event Made(Liquid indexed liquid, IERC20Metadata indexed solid);

    error Nothing();
    error Thirst();
}
