// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract Liquid is ERC20, ReentrancyGuardTransient {
    using SafeERC20 for IERC20Metadata;

    uint256 public constant WATER_SUPPLY = 1e9 ether;
    string public constant WATER_NAME = "Watar";
    string public constant WATER_SYMBOL = "WATAR";

    Liquid public immutable WATER = this;
    address public immutable GOD = 0xEbCaD83FeAD16e7D18DD691fFD2b39eca56677d8;

    IERC20Metadata public solid = IERC20Metadata(address(0xdead));

    function melt(uint256 solids) external nonReentrant {
        solid.safeTransferFrom(msg.sender, address(this), solids);
        _mint(address(this), solids);
        _mint(msg.sender, solids);
        emit Melted(this, solids);
    }

    function freeze(uint256 liquids) external nonReentrant returns (uint256 solids) {
        uint256 total = totalSupply();
        uint256 pool = balanceOf(address(this));
        uint256 held = total - pool;
        uint256 ours = 2 * liquids * pool / total;
        uint256 mine = 2 * liquids * held / total;
        solids = liquids * solid.balanceOf(address(this)) / held;
        _burn(address(this), ours);
        _burn(msg.sender, mine);
        solid.safeTransfer(msg.sender, solids);
        emit Frozen(this, liquids, solids);
    }

    function balances() public view returns (uint256 pool, uint256 lake) {
        pool = balanceOf(address(this));
        lake = WATER.balanceOf(address(this));
    }

    function buyQuote(uint256 pool, uint256 lake, uint256 liquids) public pure returns (uint256 water) {
        if (pool <= liquids) {
            revert Thirsty(pool, liquids);
        }
        uint256 area = pool * lake;
        uint256 newWet = pool - liquids;
        uint256 newOnes = area / newWet;
        water = lake - newOnes;
    }

    function sellQuote(uint256 pool, uint256 lake, uint256 liquids) public pure returns (uint256 water) {
        uint256 area = pool * lake;
        uint256 newWet = pool + liquids;
        uint256 newOnes = area / newWet;
        water = newOnes - lake;
    }

    function buyQuote(uint256 liquids) public view returns (uint256 water) {
        (uint256 pool, uint256 lake) = balances();
        water = buyQuote(pool, lake, liquids);
    }

    function sellQuote(uint256 liquids) public view returns (uint256 water) {
        (uint256 pool, uint256 lake) = balances();
        water = sellQuote(pool, lake, liquids);
    }

    function buyWithQuote(uint256 water) public view returns (uint256 liquids) {
        (uint256 pool, uint256 lake) = balances();
        liquids = sellQuote(lake, pool, water);
    }

    function sellForQuote(uint256 water) public view returns (uint256 liquids) {
        (uint256 pool, uint256 lake) = balances();
        water = buyQuote(lake, pool, liquids);
    }

    function buy(uint256 liquids) external returns (uint256 water) {
        water = buyQuote(liquids);
        bought(liquids, water);
    }

    function sell(uint256 liquids) external returns (uint256 water) {
        water = sellQuote(liquids);
        sold(liquids, water);
    }

    function buyWith(uint256 water) external returns (uint256 liquids) {
        liquids = buyWithQuote(water);
        bought(liquids, water);
    }

    function sellFor(uint256 water) external returns (uint256 liquids) {
        liquids = sellForQuote(water);
        sold(liquids, water);
    }

    function bought(uint256 liquids, uint256 water) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(WATER).transfer(address(this), water);
        _transfer(address(this), msg.sender, liquids);
        emit Bought(this, liquids, water);
    }

    function sold(uint256 liquids, uint256 water) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(WATER).transferFrom(address(this), msg.sender, water);
        _transfer(msg.sender, address(this), liquids);
        emit Sold(this, liquids, water);
    }

    function name() public view virtual override returns (string memory) {
        return this == WATER ? WATER_NAME : solid.name();
    }

    function symbol() public view virtual override returns (string memory) {
        return this == WATER ? WATER_SYMBOL : solid.symbol();
    }

    function predict(IERC20Metadata stuff) public view returns (address future, bytes32 salt) {
        if (address(stuff) == address(0)) {
            revert Nothing();
        }
        salt = bytes32(uint256(uint160(address(stuff))));
        future = Clones.predictDeterministicAddress(address(WATER), salt, address(WATER));
    }

    function make(IERC20Metadata stuff) public returns (Liquid liquid) {
        if (this == WATER) {
            bytes32 salt;
            address future;
            (future, salt) = predict(stuff);
            liquid = Liquid(future);

            if (future.code.length == 0) {
                future = Clones.cloneDeterministic(address(WATER), salt);
                liquid.__initialize(stuff);
                emit Made(stuff, liquid);
            }
        } else {
            liquid = WATER.make(stuff);
        }
    }

    function __initialize(IERC20Metadata stuff) public {
        if (address(solid) == address(0)) {
            solid = stuff;
        }
    }

    constructor() ERC20("", "") {
        _mint(GOD, WATER_SUPPLY);
    }

    event Melted(Liquid indexed liquid, uint256 liquids);
    event Frozen(Liquid indexed liquid, uint256 liquids, uint256 solids);
    event Bought(Liquid indexed liquid, uint256 liquids, uint256 water);
    event Sold(Liquid indexed liquid, uint256 liquids, uint256 water);
    event Made(IERC20Metadata indexed solid, Liquid indexed liquid);

    error Nothing();
    error Thirsty(uint256 pool, uint256 liquids);
}
