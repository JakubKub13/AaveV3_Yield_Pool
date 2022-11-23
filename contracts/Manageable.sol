//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Manageable is Ownable {
    address private _manager;
    
    event ManagerTransferred(address indexed previousManager, address indexed newManager);

    modifier onlyManager() {
        require(manager() == msg.sender, "Manageable: Caller is not a manager");
        _;
    }

    modifier onlyManagerOrOwner() {
        require(manager() == msg.sender || owner() == msg.sender, "Manageable: Caller is not a manager or owner");
        _;
    }

    function manager() public view virtual returns (address) {
        return _manager;
    }

    function setManager(address newManager) external onlyOwner returns (bool) {
        return _setManager(newManager);
    }

    function _setManager(address newManager) private returns (bool) {
        address _previousManager = _manager;
        require(newManager != _previousManager, "Manageable: Already a manager");
        _manager = newManager;
        emit ManagerTransferred(_previousManager, newManager);
        return true;
    }
}