// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ILiquid} from "iliquid/ILiquid.sol";
import {ERC20, IERC20Metadata} from "erc20/ERC20.sol";
import {SafeERC20} from "erc20/SafeERC20.sol";
import {Clones} from "clones/Clones.sol";
import {Math} from "math/Math.sol";
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
        return string.concat("l", solid.symbol());
    }

    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return solid.decimals();
    }

    function pool() public view returns (uint256 S, uint256 E) {
        S = balanceOf(address(this));
        E = HUB.balanceOf(address(this));
    }

    function mass() public view returns (uint256) {
        return solid.balanceOf(address(this));
    }

    function heats(uint256 s) public view returns (uint256 u, uint256 p) {
        if (this == HUB) {
            u = s;
        } else {
            (u, p) = heats(s, 0);
            u = s;
            //u = Math.sqrt(s * E);
        }
    }

    function heat(uint256 s) external returns (uint256 u, uint256 p) {
        if (this == HUB) {
            u = s;
            emit Heat(this, s, 0, u);
            _mint(msg.sender, u);
        } else {
            (u, p) = heats(s);
            _mint(msg.sender, u);
            _mint(address(this), 2 * mass() - u);
        }
    }

    // @param u is the amount of unpooled Spoke returned to the user
    function heats(uint256 s, uint256 e) public view notHub returns (uint256 u, uint256 p) {
        p;
        (uint256 S, uint256 E) = pool();
        u = Math.sqrt((S + s) * (E + e)) - Math.sqrt(S * E);
    }

    function heat(uint256 s, uint256 e) public nonReentrant returns (uint256 u, uint256 p) {
        (u, p) = heats(s, e);
        emit Heat(this, s, e, u);
        if (s > 0) solid.safeTransferFrom(msg.sender, address(this), s);
        if (e > 0) HUB.update(msg.sender, address(this), e);
        _mint(msg.sender, u);
        _mint(address(this), 2 * mass() - u);
    }

    function cools(uint256 u) public view returns (uint256 s, uint256 p) {
        p;
        if (this == HUB) {
            s = u;
        } else {
            s = u;
        }
    }

    function cool(uint256 u) external returns (uint256 s, uint256 p) {
        if (this == HUB) {
            s = u;
            emit Cool(this, s, 0, u);
            _burn(msg.sender, u);
            solid.safeTransfer(msg.sender, s);
        } else {
            (s, p) = cools(u);
            _burn(msg.sender, s);
            _burn(address(this), 2 * mass() - s);
        }
    }

    function cools(uint256 u, uint256 e) public view notHub returns (uint256 s, uint256 p) {
        p;
        (uint256 S, uint256 E) = pool();
        u = Math.sqrt(S * e + s * (E + e));
    }

    function cool(uint256 u, uint256 e) external returns (uint256 s, uint256 p) {
        (s, p) = cools(u, e);
        emit Cool(this, u, e, s);
        solid.safeTransfer(msg.sender, s);
        _burn(msg.sender, u);
        _burn(address(this), 2 * mass() - u);
    }

    function sells(uint256 x, uint256 X, uint256 Y) public pure returns (uint256 y) {
        y = Y - (Y * X) / (X + x);
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
        s = S - (S * E) / (E + e);
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

    modifier notHub() {
        _notHub();
        _;
    }

    function _notHub() private view {
        if (msg.sender == address(HUB)) {
            revert HubNotPool();
        }
    }

    modifier onlyLiquid() {
        _onlyLiquid();
        _;
    }

    function _onlyLiquid() private view {
        (, address home,) = HUB.made(Liquid(msg.sender).solid());
        if (msg.sender != address(HUB) && msg.sender != home) {
            revert Unauthorized();
        }
    }
}
