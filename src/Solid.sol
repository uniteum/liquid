// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ERC20} from "erc20/ERC20.sol";
import {Clones} from "clones/Clones.sol";
import {ReentrancyGuardTransient} from "reentrancy/ReentrancyGuardTransient.sol";

contract Solid is ERC20, ReentrancyGuardTransient {
    uint256 public constant MOLE = 6.02214076e23;
    uint256 constant MOLES = 10000;
    uint256 constant SUPPLY = MOLES * MOLE;
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

    function make(string calldata n, string calldata s) external payable returns (Solid sol) {
        if (this != NOTHING) {
            sol = NOTHING.make{value: msg.value}(n, s);
        } else {
            if (msg.value < 0.001 ether) revert LowPayment();
            (address location, bytes32 salt) = made(n, s);
            if (location.code.length != 0) revert AlreadyMade();
            sol = Solid(payable(location));
            location = Clones.cloneDeterministic(address(NOTHING), salt, 0);
            sol.zzz_{value: msg.value}(n, s, msg.sender);
            emit Make(this, n, s);
        }
    }

    function zzz_(string calldata n, string calldata s, address creator) external payable {
        if (bytes(_symbol).length == 0) {
            _name = n;
            _symbol = s;
            uint256 creatorShare = SUPPLY / 100;
            uint256 poolShare = SUPPLY - creatorShare;
            _mint(address(this), poolShare);
            _mint(creator, creatorShare);
        }
    }

    event Make(Solid indexed solid, string indexed name, string indexed symbol);
    event Deposit(Solid indexed solid, uint256 sol, uint256 eth);
    event Withdraw(Solid indexed solid, uint256 sol, uint256 eth);

    error Nothing();
    error WithdrawFailed();
    error LowPayment();
    error AlreadyMade();
}
