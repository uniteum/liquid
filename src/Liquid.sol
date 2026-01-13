// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ERC20, IERC20Metadata} from "erc20/ERC20.sol";
import {SafeERC20} from "erc20/SafeERC20.sol";
import {Clones} from "clones/Clones.sol";
import {ReentrancyGuardTransient} from "reentrancy/ReentrancyGuardTransient.sol";

contract Liquid is ERC20, ReentrancyGuardTransient {
    using SafeERC20 for IERC20Metadata;

    Liquid public immutable HUB = this;

    IERC20Metadata public solid;

    constructor(IERC20Metadata hub) ERC20("", "") {
        solid = hub;
    }

    function name() public view virtual override returns (string memory) {
        return solid.name();
    }

    function symbol() public view virtual override returns (string memory) {
        return solid.symbol();
    }

    function decimals() public view virtual override returns (uint8) {
        return solid.decimals();
    }

    function pool() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function lake() public view returns (uint256) {
        return HUB.balanceOf(address(this));
    }

    function mass() public view returns (uint256) {
        return solid.balanceOf(address(this));
    }

    function heats(uint256 solids) public view returns (uint256 pools, uint256 senders) {
        uint256 total = totalSupply() + 2 * solids;
        uint256 pooled = pool() + solids;
        uint256 unpooled = total - pooled;
        pools = 2 * solids * pooled / total;
        senders = 2 * solids * unpooled / total;
    }

    function heat(uint256 solids) external nonReentrant returns (uint256 pools, uint256 senders) {
        solid.safeTransferFrom(msg.sender, address(this), solids);
        (pools, senders) = heats(solids);
        emit Heat(this, solids, pools, senders);
        _mint(address(this), pools);
        _mint(msg.sender, senders);
    }

    function cools(uint256 spokes) public view returns (uint256 solids, uint256 pools, uint256 senders) {
        uint256 total = totalSupply();
        uint256 pooled = pool();
        uint256 unpooled = total - pooled;
        pools = 2 * spokes * pooled / total;
        senders = 2 * spokes * unpooled / total;
        solids = spokes * mass() / unpooled;
    }

    function cool(uint256 spokes) external nonReentrant returns (uint256 solids, uint256 pools, uint256 senders) {
        (solids, pools, senders) = cools(spokes);
        emit Cool(this, spokes, solids, pools, senders);
        _burn(address(this), pools);
        _burn(msg.sender, senders);
        solid.safeTransfer(msg.sender, solids);
    }

    function sells(uint256 x, uint256 X, uint256 Y) public pure returns (uint256 y) {
        y = Y - Y * X / (X + x);
    }

    function sells(uint256 spokes) public view returns (uint256 hubs) {
        hubs = sells(spokes, pool(), lake());
    }

    function sell(uint256 spokes) external returns (uint256 hubs) {
        hubs = sells(spokes);
        _sell(spokes, hubs);
    }

    function sellsFor(Liquid that, uint256 spokes) public view returns (uint256 hubs, uint256 thats) {
        hubs = sells(spokes);
        thats = that.buys(hubs);
    }

    function sellFor(Liquid that, uint256 spokes) external returns (uint256 hubs, uint256 thats) {
        (hubs, thats) = sellsFor(that, spokes);
        _sell(spokes, hubs);
        that.__buy(thats, hubs);
    }

    function buys(uint256 hubs) public view returns (uint256 spokes) {
        spokes = sells(hubs, lake(), pool());
    }

    function buy(uint256 hubs) external returns (uint256 spokes) {
        spokes = buys(hubs);
        _buy(spokes, hubs);
    }

    function __buy(uint256 spokes, uint256 hubs) external onlyLiquid {
        _buy(spokes, hubs);
    }

    function _buy(uint256 spokes, uint256 hubs) private {
        HUB.update(msg.sender, address(this), hubs);
        emit Buy(this, spokes, hubs);
        _update(address(this), msg.sender, spokes);
    }

    function _sell(uint256 spokes, uint256 hubs) private {
        HUB.update(address(this), msg.sender, hubs);
        emit Sell(this, spokes, hubs);
        _update(msg.sender, address(this), spokes);
    }

    function update(address from, address to, uint256 amount) external onlyLiquid {
        _update(from, to, amount);
    }

    function made(IERC20Metadata backing) public view returns (bool yes, address home, bytes32 salt) {
        if (address(backing) == address(0)) {
            revert Nothing();
        }
        salt = bytes32(uint256(uint160(address(backing))));
        home = Clones.predictDeterministicAddress(address(HUB), salt, address(HUB));
        yes = home.code.length != 0;
    }

    function make(IERC20Metadata backing) public returns (Liquid liquid) {
        if (this != HUB) {
            liquid = HUB.make(backing);
        } else {
            (bool yes, address home, bytes32 salt) = made(backing);
            liquid = Liquid(home);
            if (!yes) {
                emit Make(liquid, backing);
                home = Clones.cloneDeterministic(address(HUB), salt, 0);
                liquid.zzz_(backing);
            }
        }
    }

    function zzz_(IERC20Metadata backing) external {
        if (address(solid) == address(0)) {
            solid = backing;
        }
    }

    modifier onlyLiquid() {
        _onlyLiquid();
        _;
    }

    function _onlyLiquid() private view {
        (, address home,) = HUB.made(Liquid(msg.sender).solid());
        if (msg.sender != home) {
            revert Unauthorized();
        }
    }

    event Heat(Liquid indexed liquid, uint256 solids, uint256 pools, uint256 senders);
    event Cool(Liquid indexed liquid, uint256 liquids, uint256 solids, uint256 pools, uint256 senders);
    event Buy(Liquid indexed liquid, uint256 liquids, uint256 hubs);
    event Sell(Liquid indexed liquid, uint256 liquids, uint256 hubs);
    event Make(Liquid indexed liquid, IERC20Metadata indexed solid);

    error Nothing();
    error Unauthorized();
}
