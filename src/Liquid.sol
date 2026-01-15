// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ILiquid} from "iliquid/ILiquid.sol";
import {ERC20, IERC20Metadata} from "erc20/ERC20.sol";
import {SafeERC20} from "erc20/SafeERC20.sol";
import {Clones} from "clones/Clones.sol";
import {ReentrancyGuardTransient} from "reentrancy/ReentrancyGuardTransient.sol";

contract Liquid is ILiquid, ERC20, ReentrancyGuardTransient {
    using SafeERC20 for IERC20Metadata;

    Liquid public immutable HUB = this;

    IERC20Metadata public solid;

    constructor(IERC20Metadata hub) ERC20("", "") {
        solid = hub;
    }

    function name() public view virtual override(ERC20, IERC20Metadata) returns (string memory) {
        return solid.name();
    }

    function symbol() public view virtual override(ERC20, IERC20Metadata) returns (string memory) {
        return solid.symbol();
    }

    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return solid.decimals();
    }

    function pool() public view returns (uint256 S, uint256 E) {
        S = balanceOf(address(this));
        E = HUB.balanceOf(address(this));
    }

    function lake() public view returns (uint256) {
        return HUB.balanceOf(address(this));
    }

    function mass() public view returns (uint256) {
        return solid.balanceOf(address(this));
    }

    function heats(uint256 solids) public view returns (uint256 pools, uint256 senders) {
        uint256 total = totalSupply() + 2 * solids;
        (uint256 pooled,) = pool();
        pooled += solids;
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
        (uint256 pooled,) = pool();
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

    function sells(uint256 s) public view returns (uint256 e) {
        (uint256 S, uint256 E) = pool();
        e = E - (E * S + E - 1) / (S + s);
    }

    function sell(uint256 spokes) external returns (uint256 hubs) {
        hubs = sells(spokes);
        _sell(spokes, hubs);
    }

    function sellsFor(ILiquid that, uint256 spokes) public view returns (uint256 hubs, uint256 thats) {
        hubs = sells(spokes);
        thats = that.buys(hubs);
    }

    function sellFor(ILiquid that, uint256 spokes) external returns (uint256 hubs, uint256 thats) {
        (hubs, thats) = sellsFor(that, spokes);
        _sell(spokes, hubs);
        Liquid(address(that)).__buy(thats, hubs);
    }

    function buys(uint256 e) public view returns (uint256 s) {
        (uint256 S, uint256 E) = pool();
        s = S - S * E / (E + e);
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

    function made(IERC20Metadata backing) public view returns (bool cloned, address home, bytes32 salt) {
        if (address(backing) == address(0)) {
            revert Nothing();
        }
        salt = bytes32(uint256(uint160(address(backing))));
        home = Clones.predictDeterministicAddress(address(HUB), salt, address(HUB));
        cloned = home.code.length != 0;
    }

    function make(IERC20Metadata backing) public returns (ILiquid liquid) {
        if (this != HUB) {
            liquid = HUB.make(backing);
        } else {
            (bool cloned, address home, bytes32 salt) = made(backing);
            liquid = Liquid(home);
            if (!cloned) {
                emit Make(liquid, backing);
                home = Clones.cloneDeterministic(address(HUB), salt, 0);
                Liquid(home).zzz_(backing);
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
}
