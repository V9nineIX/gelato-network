pragma solidity ^0.5.10;

import '../../../1_gelato_standards/3_GTA_standards/gelato_trigger_standards/IGelatoTrigger.sol';

contract GelatoTriggerRegistry {
    // to make clear that this is not a standalone-deployment contract
    constructor() internal {}

    // trigger => bool
    mapping(address => bool) public triggers;

    function _getTriggerSelector(address _trigger)
        internal
        view
        returns(bytes4 triggerSelector)
    {
        triggerSelector = IGelatoTrigger(_trigger).triggerSelector();
    }

    // ____________ Register Trigger ____________
    event LogTriggerRegistered(address indexed _registrator,
                               address indexed _triggerAddress
    );
    function _registerTrigger(address _triggerAddress)
        internal
    {
        triggers[_triggerAddress] = true;
        emit LogTriggerRegistered(msg.sender,
                                  _triggerAddress
        );
    }
    // ===========

    // ____________ Deregister Trigger ____________
    event LogTriggerDeregistered(address indexed _registrator,
                                 address indexed _triggerAddress
    );
    function _deregisterTrigger(address _triggerAddress)
        internal
    {
        triggers[_triggerAddress] = false;
        emit LogTriggerDeregistered(msg.sender, _triggerAddress);
    }
    // ===========

    // ____________ Standard Checks _____________________________________
    modifier onlyRegisteredTriggers(address _trigger)
    {
        require(triggers[_trigger],
            "GelatoTriggerRegistry.onlyRegisteredTriggers: failed"
        );
        _;
    }
    // ===========
}