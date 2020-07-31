// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Contract module which allows smart contract to be stopped--and never restarted again.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotStopped` and `whenStopped`, which can be applied to
 * the functions of your contract. Note that they will not be stoppable by
 * simply including this module, only once the modifiers are put in place.
 */
contract Stoppable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Stopped(address account);

    bool private _stopped;

    /**
     * @dev Initializes the contract in unstopped state.
     */
    constructor () internal {
        _stopped = false;
    }

    /**
     * @dev Returns true if the contract is stopped, and false otherwise.
     */
    function stopped() public view returns (bool) {
        return _stopped;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not stopped.
     *
     * Requirements:
     *
     * - The contract must not be stopped.
     */
    modifier whenNotStopped() {
        require(!_stopped, "Stoppable: stopped");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenStopped() {
        require(_stopped, "Stoppable: not stopped");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be stopped.
     */
    function _stop() internal whenNotStopped {
        _stopped = true;
        emit Stopped(msg.sender);
    }
}
