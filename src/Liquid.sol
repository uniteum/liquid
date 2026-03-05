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
        return solid.symbol();
    }

    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return solid.decimals();
    }

    function pool() public view returns (uint256 P, uint256 E) {
        P = balanceOf(address(this));
        E = HUB.balanceOf(address(this));
    }

    function mass() public view returns (uint256) {
        return solid.balanceOf(address(this));
    }

    function heats(uint256 m) public view returns (uint256 u, uint256 p) {
        if (this == HUB) {
            u = m;
        } else {
            uint256 T = totalSupply();
            uint256 P = balanceOf(address(this));
            p = (2 * m * P) / T;
            u = 2 * m - p;
        }
    }

    function heat(uint256 m) external nonReentrant returns (uint256 u, uint256 p) {
        if (this == HUB) {
            u = m;
            emit Heat(this, m, 0, u);
            _mint(msg.sender, u);
        } else {
            (u, p) = heats(m);
            emit Heat(this, m, p, u);
            solid.safeTransferFrom(msg.sender, address(this), m);
            _mint(msg.sender, u);
            _mint(address(this), p);
        }
    }

    // @param u is the amount of unpooled Spoke returned to the user
    function heats(uint256 m, uint256 e) public view notHub returns (uint256 u, uint256 p) {
        (uint256 P, uint256 E) = pool();
        m = m + (e * (P + m)) / (E + e);
        uint256 T = totalSupply();
        if (T == 0) {
            p = m;
        } else {
            p = (2 * m * P) / T;
        }
        u = 2 * m - p;
        p = u;
    }

    function heat(uint256 m, uint256 e) public nonReentrant returns (uint256 u, uint256 p) {
        (u, p) = heats(m, e);
        emit Heat(this, m, e, u);
        if (m > 0) solid.safeTransferFrom(msg.sender, address(this), m);
        if (e > 0) HUB.update(msg.sender, address(this), e);
        _mint(msg.sender, u);
        _mint(address(this), p);
    }

    function cools(uint256 u) public view returns (uint256 m, uint256 p) {
        if (this == HUB) {
            m = u;
        } else {
            uint256 T = totalSupply();
            uint256 P = balanceOf(address(this));
            uint256 U = T - P;
            m = (u * T) / U / 2;
            p = 2 * m - u;
        }
    }

    function cool(uint256 u) external nonReentrant returns (uint256 m, uint256 p) {
        if (this == HUB) {
            m = u;
            emit Cool(this, m, 0, u);
            _burn(msg.sender, u);
            solid.safeTransfer(msg.sender, m);
        } else {
            (m, p) = cools(u);
            emit Cool(this, u, 0, m);
            solid.safeTransfer(msg.sender, m);
            _burn(msg.sender, u);
            _burn(address(this), p);
        }
    }

    function cools(uint256 u, uint256 e) public view notHub returns (uint256 m, uint256 p) {
        (uint256 P, uint256 E) = pool();
        uint256 T = totalSupply();
        uint256 U = T - P;

        // Base solid from liquid (same as cools(u))
        m = (u * T) / U / 2;
        p = 2 * m - u;

        // Add hub contribution: hub converts to solid at mass()/E rate
        if (e > 0 && E > 0) {
            m = m + (e * mass()) / E;
        }
    }

    function cool(uint256 u, uint256 e) external nonReentrant returns (uint256 m, uint256 p) {
        (m, p) = cools(u, e);
        emit Cool(this, u, e, m);
        if (e > 0) HUB.update(address(this), msg.sender, e);
        solid.safeTransfer(msg.sender, m);
        _burn(msg.sender, u);
        _burn(address(this), p);
    }

    function sells(uint256 s) public view returns (uint256 e) {
        (uint256 S, uint256 E) = pool();
        e = E - (E * S + E - 1) / (S + s);
    }

    function sell(uint256 s) external nonReentrant returns (uint256 e) {
        e = sells(s);
        _sell(s, e);
    }

    function sellsFor(ILiquid that, uint256 s) public view returns (uint256 e, uint256 thats) {
        e = sells(s);
        thats = that.buys(e);
    }

    function sellFor(ILiquid that, uint256 s) external nonReentrant returns (uint256 e, uint256 thats) {
        (e, thats) = sellsFor(that, s);
        // Transfer spokes from user to this pool
        emit Sell(this, s, e);
        _update(msg.sender, address(this), s);
        // Route hubs from this pool to target pool, spokes from target pool to user
        HUB.update(address(this), address(that), e);
        emit Buy(that, thats, e);
        Liquid(address(that)).update(address(that), msg.sender, thats);
    }

    function buys(uint256 e) public view returns (uint256 s) {
        (uint256 S, uint256 E) = pool();
        s = S - (S * E) / (E + e);
    }

    function buy(uint256 e) external nonReentrant returns (uint256 s) {
        s = buys(e);
        _buy(s, e);
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
        if (address(solid) != address(0)) {
            revert Unauthorized();
        }
        solid = backing;
    }

    modifier notHub() {
        _notHub();
        _;
    }

    function _notHub() private view {
        if (address(this) == address(HUB)) {
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
