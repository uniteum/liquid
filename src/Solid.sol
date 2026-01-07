// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "erc20/ERC20.sol";
import {Clones} from "clones/Clones.sol";
import {ReentrancyGuardTransient} from "reentrancy/ReentrancyGuardTransient.sol";
import {ISolid} from "./ISolid.sol";

contract Solid is ISolid, ERC20, ReentrancyGuardTransient {
    uint256 constant MOLE = 6.02214076e23;
    uint256 constant MOLES = 10000;
    uint256 constant SUPPLY = MOLES * MOLE;
    uint256 constant MAKER_PAYMENT = 0.001 ether;
    uint256 constant MAKER_SHARE = SUPPLY / 100;
    uint256 constant POOL_SHARE = SUPPLY - MAKER_SHARE;
    Solid public immutable NOTHING = this;

    constructor() ERC20("", "") {}

    function pool() public view returns (uint256 solPool, uint256 ethPool) {
        solPool = balanceOf(address(this));
        ethPool = address(this).balance;
    }

    function withdraw(uint256 sol) external nonReentrant returns (uint256 eth) {
        (uint256 solPool, uint256 ethPool) = pool();
        eth = ethPool - ethPool * solPool / (solPool + sol);
        _update(msg.sender, address(this), sol);
        emit Withdraw(this, sol, eth);
        (bool ok, bytes memory returnData) = msg.sender.call{value: eth}("");
        if (!ok) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(returnData, 32), mload(returnData))
                }
            } else {
                revert WithdrawFailed();
            }
        }
    }

    function deposit() public payable returns (uint256 sol) {
        (uint256 solPool, uint256 ethPool) = pool();
        uint256 eth = msg.value;
        sol = solPool - solPool * (ethPool - eth) / ethPool;
        _update(address(this), msg.sender, sol);
        emit Deposit(this, eth, sol);
    }

    receive() external payable {
        deposit();
    }

    function made(string calldata n, string calldata s) public view returns (address location, bytes32 salt) {
        if (bytes(n).length == 0 || bytes(s).length == 0) {
            revert Nothing();
        }
        salt = keccak256(abi.encode(n, s));
        location = Clones.predictDeterministicAddress(address(NOTHING), salt, address(NOTHING));
    }

    function make(string calldata n, string calldata s) external payable returns (ISolid sol) {
        if (this != NOTHING) {
            sol = NOTHING.make{value: msg.value}(n, s);
            require(sol.transfer(msg.sender, MAKER_SHARE), "Transfer failed");
        } else {
            if (msg.value < MAKER_PAYMENT) revert LowPayment();
            (address location, bytes32 salt) = made(n, s);
            if (location.code.length != 0) revert AlreadyMade();
            sol = ISolid(payable(location));
            location = Clones.cloneDeterministic(address(NOTHING), salt, 0);
            Solid(payable(address(sol))).zzz_{value: msg.value}(n, s, msg.sender);
            emit Make(sol, n, s);
        }
    }

    function zzz_(string calldata n, string calldata s, address maker) external payable {
        if (bytes(_symbol).length == 0) {
            _name = n;
            _symbol = s;
            _mint(address(this), POOL_SHARE);
            _mint(maker, MAKER_SHARE);
        }
    }
}
