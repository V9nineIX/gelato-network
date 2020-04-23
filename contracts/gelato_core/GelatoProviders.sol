pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import { IGelatoProviders } from "./interfaces/IGelatoProviders.sol";
import { GelatoSysAdmin } from "./GelatoSysAdmin.sol";
import { Address } from "../external/Address.sol";
import { SafeMath } from "../external/SafeMath.sol";
import { Math } from "../external/Math.sol";
import { IGelatoProviderModule } from "./interfaces/IGelatoProviderModule.sol";
import { ProviderModuleSet } from "../libraries/ProviderModuleSet.sol";
import { Action, Operation, TaskReceipt } from "./interfaces/IGelatoCore.sol";
import { GelatoString } from "../libraries/GelatoString.sol";
import { IGelatoCondition } from "../gelato_conditions/IGelatoCondition.sol";

/// @title GelatoProviders
/// @notice Provider Management API - Whitelist TaskSpecs
/// @dev Find all NatSpecs inside IGelatoProviders
abstract contract GelatoProviders is IGelatoProviders, GelatoSysAdmin {

    using Address for address payable;  /// for sendValue method
    using ProviderModuleSet for ProviderModuleSet.Set;
    using SafeMath for uint256;
    using GelatoString for string;

    // This is only for internal use by taskSpecHash()
    struct NoDataAction {
        address inst;
        Operation operation;
        bool termsOkCheck;
        bool value;
    }

    uint256 public constant override NO_CEIL = 2**256 - 1;  // MaxUint256

    mapping(address => uint256) public override providerFunds;
    mapping(address => uint256) public override executorStake;
    mapping(address => address) public override executorByProvider;
    mapping(address => uint256) public override executorProvidersCount;
    // The Condition-Actions-Combo Gas-Price-Ceil => taskSpecGasPriceCeil
    mapping(address => mapping(bytes32 => uint256)) public override taskSpecGasPriceCeil;
    mapping(address => ProviderModuleSet.Set) internal _providerModules;

    // GelatoCore: submitTask Gate
    function isTaskSpecProvided(
        address _provider,
        IGelatoCondition _condition,
        Action[] memory _actions
    )
        public
        view
        override
        returns(string memory)
    {
        bytes32 taskSpecHash = taskSpecHash(_condition, _actions);
        if (taskSpecGasPriceCeil[_provider][taskSpecHash] == 0) return "TaskSpecNotProvided";
        return OK;
    }

    // IGelatoProviderModule: GelatoCore submitTask/canExec Gate
    function providerModuleChecks(TaskReceipt memory _TR)
        public
        view
        override
        returns(string memory)
    {
        if (!isModuleProvided(_TR.task.provider.addr, _TR.task.provider.module))
            return "InvalidProviderModule";

        IGelatoProviderModule providerModule = IGelatoProviderModule(
            _TR.task.provider.module
        );

        try providerModule.isProvided(_TR) returns(string memory res) {
            return res;
        } catch {
            return "GelatoProviders.providerModuleChecks";
        }
    }

    // GelatoCore: combined submitTask Gate
    function isTaskProvided(TaskReceipt memory _TR)
        public
        view
        override
        returns(string memory res)
    {
        res = isTaskSpecProvided(_TR.task.provider.addr, _TR.task.condition.inst, _TR.task.actions);
        if (res.startsWithOk()) return providerModuleChecks(_TR);
    }

    // GelatoCore canExec Gate
    function providerCanExec(TaskReceipt memory _TR, uint256 _gelatoGasPrice)
        public
        view
        override
        returns(string memory)
    {
        // Will only return if a) action is not whitelisted & b) gelatoGasPrice is higher than gasPriceCeiling
        bytes32 taskSpecHash = taskSpecHash(_TR.task.condition.inst, _TR.task.actions);
        if (_gelatoGasPrice > taskSpecGasPriceCeil[_TR.task.provider.addr][taskSpecHash])
            return "taskSpecGasPriceCeil-OR-notProvided";
        return providerModuleChecks(_TR);
    }

    // Provider Funding
    function provideFunds(address _provider) public payable override {
        require(msg.value > 0, "GelatoProviders.provideFunds: zero value");
        uint256 newProviderFunds = providerFunds[_provider].add(msg.value);
        emit LogProvideFunds(_provider, msg.value, newProviderFunds);
        providerFunds[_provider] = newProviderFunds;
    }

    // @dev change to withdraw funds
    function unprovideFunds(uint256 _withdrawAmount)
        public
        override
        returns(uint256 realWithdrawAmount)
    {
        uint256 previousProviderFunds = providerFunds[msg.sender];
        realWithdrawAmount = Math.min(_withdrawAmount, previousProviderFunds);
        uint256 newProviderFunds = previousProviderFunds - realWithdrawAmount;

        // Effects
        providerFunds[msg.sender] = newProviderFunds;

        // Interaction
        msg.sender.sendValue(realWithdrawAmount);

        emit LogUnprovideFunds(msg.sender, realWithdrawAmount, newProviderFunds);
    }

    // Called by Providers
    function providerAssignsExecutor(address _newExecutor) public override {
        address currentExecutor = executorByProvider[msg.sender];

        // CHECKS
        require(
            currentExecutor != _newExecutor,
            "GelatoProviders.providerAssignsExecutor: already assigned."
        );
        if (_newExecutor != address(0)) {
            require(
                isExecutorMinStaked(_newExecutor),
                "GelatoProviders.providerAssignsExecutor: isExecutorMinStaked()"
            );
        }

        // EFFECTS: Provider reassigns from currentExecutor to newExecutor (or no executor)
        if (currentExecutor != address(0)) executorProvidersCount[currentExecutor]--;
        executorByProvider[msg.sender] = _newExecutor;
        if (_newExecutor != address(0)) executorProvidersCount[_newExecutor]++;

        emit LogProviderAssignsExecutor(msg.sender, currentExecutor, _newExecutor);
    }

    // Called by Executors
    function executorAssignsExecutor(address _provider, address _newExecutor) public override {
        address currentExecutor = executorByProvider[_provider];

        // CHECKS
        require(
            currentExecutor == msg.sender,
            "GelatoProviders.executorAssignsExecutor: msg.sender is not assigned executor"
        );
        require(
            currentExecutor != _newExecutor,
            "GelatoProviders.executorAssignsExecutor: already assigned."
        );
        // Checks at the same time if _nexExecutor != address(0)
        require(
            isExecutorMinStaked(_newExecutor),
            "GelatoProviders.executorAssignsExecutor: isExecutorMinStaked()"
        );

        // EFFECTS: currentExecutor reassigns to newExecutor
        executorProvidersCount[currentExecutor]--;
        executorByProvider[_provider] = _newExecutor;
        executorProvidersCount[_newExecutor]++;

        emit LogExecutorAssignsExecutor(_provider, currentExecutor, _newExecutor);
    }

    // (Un-)provide Condition Action Combos at different Gas Price Ceils
    function provideTaskSpecs(TaskSpec[] memory _TaskSpecs) public override {
        for (uint i; i < _TaskSpecs.length; i++) {
            if (_TaskSpecs[i].gasPriceCeil == 0) _TaskSpecs[i].gasPriceCeil = NO_CEIL;
            bytes32 taskSpecHash = taskSpecHash(_TaskSpecs[i].condition, _TaskSpecs[i].actions);
            setTaskSpecGasPriceCeil(taskSpecHash, _TaskSpecs[i].gasPriceCeil);
            emit LogProvideTaskSpec(msg.sender, taskSpecHash);
        }
    }

    function unprovideTaskSpecs(TaskSpec[] memory _TaskSpecs) public override {
        for (uint i; i < _TaskSpecs.length; i++) {
            bytes32 taskSpecHash = taskSpecHash(_TaskSpecs[i].condition, _TaskSpecs[i].actions);
            require(
                taskSpecGasPriceCeil[msg.sender][taskSpecHash] != 0,
                "GelatoProviders.unprovideTaskSpecs: redundant"
            );
            delete taskSpecGasPriceCeil[msg.sender][taskSpecHash];
            emit LogUnprovideTaskSpec(msg.sender, taskSpecHash);
        }
    }

    function setTaskSpecGasPriceCeil(bytes32 _taskSpecHash, uint256 _gasPriceCeil) public override {
            uint256 currentTaskSpecGasPriceCeil = taskSpecGasPriceCeil[msg.sender][_taskSpecHash];
            require(
                currentTaskSpecGasPriceCeil != _gasPriceCeil,
                "GelatoProviders.setTaskSpecGasPriceCeil: redundant"
            );
            taskSpecGasPriceCeil[msg.sender][_taskSpecHash] = _gasPriceCeil;
            emit LogSetTaskSpecGasPriceCeil(
                msg.sender,
                _taskSpecHash,
                currentTaskSpecGasPriceCeil,
                _gasPriceCeil
            );
    }

    // Provider Module
    function addProviderModules(IGelatoProviderModule[] memory _modules) public override {
        for (uint i; i < _modules.length; i++) {
            require(
                !isModuleProvided(msg.sender, _modules[i]),
                "GelatoProviders.addProviderModules: redundant"
            );
            _providerModules[msg.sender].add(_modules[i]);
            emit LogAddProviderModule(msg.sender, _modules[i]);
        }
    }

    function removeProviderModules(IGelatoProviderModule[] memory _modules) public override {
        for (uint i; i < _modules.length; i++) {
            require(
                isModuleProvided(msg.sender, _modules[i]),
                "GelatoProviders.removeProviderModules: redundant"
            );
            _providerModules[msg.sender].remove(_modules[i]);
            emit LogRemoveProviderModule(msg.sender, _modules[i]);
        }
    }

    // Batch (un-)provide
    function multiProvide(
        address _executor,
        TaskSpec[] memory _TaskSpecs,
        IGelatoProviderModule[] memory _modules
    )
        public
        payable
        override
    {
        if (msg.value != 0) provideFunds(msg.sender);
        if (_executor != address(0)) providerAssignsExecutor(_executor);
        provideTaskSpecs(_TaskSpecs);
        addProviderModules(_modules);
    }

    function multiUnprovide(
        uint256 _withdrawAmount,
        TaskSpec[] memory _TaskSpecs,
        IGelatoProviderModule[] memory _modules
    )
        public
        override
    {
        if (_withdrawAmount != 0) unprovideFunds(_withdrawAmount);
        unprovideTaskSpecs(_TaskSpecs);
        removeProviderModules(_modules);
    }

    // Provider Liquidity
    function minExecProviderFunds(uint256 _gelatoMaxGas, uint256 _gelatoGasPrice)
        public
        view
        override
        returns(uint256)
    {
        uint256 maxExecTxCost = (EXEC_TX_OVERHEAD + _gelatoMaxGas) * _gelatoGasPrice;
        return maxExecTxCost + (maxExecTxCost * totalSuccessShare) / 100;
    }

    function isProviderLiquid(
        address _provider,
        uint256 _gelatoMaxGas,
        uint256 _gelatoGasPrice
    )
        public
        view
        override
        returns(bool)
    {
        return minExecProviderFunds(_gelatoMaxGas, _gelatoGasPrice) <= providerFunds[_provider];
    }

    // An Executor qualifies and remains registered for as long as he has minExecutorStake
    function isExecutorMinStaked(address _executor) public view override returns(bool) {
        return executorStake[_executor] >= minExecutorStake;
    }

    // Providers' Executor Assignment
    function isExecutorAssigned(address _executor) public view override returns(bool) {
        return executorProvidersCount[_executor] != 0;
    }

    // Helper fn that can also be called to query taskSpecHash off-chain
    function taskSpecHash(IGelatoCondition _condition, Action[] memory _actions)
        public
        view
        override
        returns(bytes32)
    {
        NoDataAction[] memory noDataActions = new NoDataAction[](_actions.length);
        for (uint i = 0; i < _actions.length; i++) {
            NoDataAction memory noDataAction = NoDataAction({
                inst: _actions[i].inst,
                operation: _actions[i].operation,
                termsOkCheck: _actions[i].termsOkCheck,
                value: _actions[i].value == 0 ? false : true
            });
            noDataActions[i] = noDataAction;
        }
        return keccak256(abi.encode(_condition, noDataActions));
    }

    // Providers' Module Getters
    function isModuleProvided(address _provider, IGelatoProviderModule _module)
        public
        view
        override
        returns(bool)
    {
        return _providerModules[_provider].contains(_module);
    }

    function providerModules(address _provider)
        external
        view
        override
        returns(IGelatoProviderModule[] memory)
    {
        return _providerModules[_provider].enumerate();
    }
}
