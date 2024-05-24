// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "../Game.sol";
import "../GameUtils.sol";

contract GameCommit is Game {
    using GameUtils for Config;

    struct Context {
        uint256 avatarID;
        address controller;
        uint24 epoch;
        bytes24 commitmentHash;
    }

    struct StateChanges {
        uint256 avatarID; // key
        uint24 epoch;
        bytes24 commitmentHash;
    }

    function commit(uint256 avatarID, bytes24 commitmentHash, address payable payee) external payable {
        Game.Store storage store = getStore();
        // 4 steps

        // 1. gather context (will be emitted)
        Context memory context = _context(store, avatarID, commitmentHash);
        // 2. compute state changes from context (pure function)
        StateChanges memory stateChanges = _stateChanges(context);
        // 3. apply state changes (zero computation)
        _apply(store, stateChanges);
        // 4. emit event
        emit Game.CommitmentMade(context.avatarID, context.controller, context.epoch, context.commitmentHash);

        // extra steps for which we do not intend to track via events
        if (payee != address(0) && msg.value != 0) {
            payee.transfer(msg.value);
        }
    }

    function _context(
        Game.Store storage store,
        uint256 avatarID,
        bytes24 commitmentHash
    ) internal view returns (Context memory context) {
        Game.Config memory config = getConfig();
        mapping(address => Game.ControllerType) storage isController = store.avatars[avatarID].controllers;
        if (isController[msg.sender] == Game.ControllerType.None) {
            revert Game.NotAuthorizedController(msg.sender);
        }
        context.avatarID = avatarID;
        context.controller = msg.sender;
        (context.epoch, ) = config.getEpoch();
        context.commitmentHash = commitmentHash;
    }

    function _stateChanges(Context memory context) public pure returns (StateChanges memory stateChanges) {
        return StateChanges({avatarID: context.avatarID, epoch: context.epoch, commitmentHash: context.commitmentHash});
    }

    function _apply(Game.Store storage store, StateChanges memory stateChanges) internal {
        store.commitments[stateChanges.avatarID] = Game.Commitment({
            hash: stateChanges.commitmentHash,
            epoch: stateChanges.epoch
        });
    }
}
