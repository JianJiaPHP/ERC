// SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.6.12;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

interface IERC20 {

    // 代币名称
    function name() external view returns (string memory);

    // 代币缩写--符号
    function symbol() external view returns (string memory);

    // 代币小数位数
    function decimals() external view returns (uint8);

    // 代币总数
    function totalSupply() external view returns (uint);

    // 账户余额
    function balanceOf(address owner) external view returns (uint);

    // 交易的发起方(谁调用这个方法，谁就是交易的发起方)把_value数量的代币发送到_to账户
    function transfer(address _to, uint256 _value) external returns (bool);

    // 从_from账户里转出_value数量的代币到_to账户
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);

    // 交易的发起方把_value数量的代币的使用权交给_spender
    // 然后_spender才能调用transferFrom方法把我账户里的钱转给另外一个人
    function approve(address _spender, uint256 _value) external returns (bool);

    // 查询_spender目前还有多少_owner账户代币的使用权
    function allowance(address _owner, address _spender) external view returns (uint256);

    // 转账成功的事件
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    // 使用权委托成功的事件
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}


// 设置代币控制合约的管理员
contract Owned {

    // modifier(条件)，表示必须是权力所有者才能操作，类似超管
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // 权力所有者
    address owner;

    // 合约创建的时候执行，执行合约的人是第一个owner
    constructor() public {
        owner = msg.sender;
    }

    // 新的owner,初始为空地址
    address newOwner = address(0);

    // 更换owner成功的事件
    event OwnerUpdate(address _prevOwner, address _newOwner);

    // 现任owner把所有权交给新的owner(需要新的owner调用acceptOwnership方法才会生效)
    function changeOwner(address _newOwner) public onlyOwner {
        require(_newOwner != owner);
        newOwner = _newOwner;
    }

    // 新的owner接受所有权,权力交替正式生效
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnerUpdate(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

// 代币的控制合约
contract Controlled is Owned{

    // 第一个会员vip
    constructor() public {
        setAdmin(msg.sender, true);
    }

    // 控制代币是否可以交易
    // true代表可以(admin 里的账户不受此限制，具体实现在下面的transferAllowed里)
    bool transferEnabled = true;

    // 是否启用账户锁定功能，true代表启用
    bool lockFlag = true;

    // 锁定的账户集合，address账户，bool是否被锁，true:被锁定，当lockFlag=true时，转不了账了
    mapping(address => bool) locked;

    // 拥有特权用户，不受transferEnabled和lockFlag的限制，vip啊，bool为true代表vip有效
    mapping(address => bool) admin;

    // 设置transferEnabled值
    function enableTransfer(bool _enable) public onlyOwner returns (bool success){
        transferEnabled=_enable;
        return true;
    }

    // 设置lockFlag值
    function disableLock(bool _enable) public onlyOwner returns (bool success){
        lockFlag=_enable;
        return true;
    }

    // 把_addr加到锁定账户里，拉黑名单。。。
    function addLock(address _addr) public onlyOwner returns (bool success){
        require(_addr!=msg.sender);
        locked[_addr]=true;
        return true;
    }

    // 设置vip用户
    function setAdmin(address _addr,bool _enable) public onlyOwner returns (bool success){
        admin[_addr]=_enable;
        return true;
    }

    // 解锁_addr用户
    function removeLock(address _addr) public onlyOwner returns (bool success){
        locked[_addr]=false;
        return true;
    }

    // 控制合约 核心实现
    modifier transferAllowed(address _addr) {
        if (!admin[_addr]) {
            require(transferEnabled,"transfer is not enabeled now!");
            if(lockFlag){
                require(!locked[_addr],"you are locked!");
            }
        }
        _;
    }

}

// 代币demo
contract MyToken is IERC20,Controlled {
    // 使用SafeMath
    using SafeMath for uint256;

    string public _name;
    string public _symbol;
    uint8 public _decimals;
    uint256 public _totalSupply;

    // 账户集合
    mapping (address => uint256) public _balanceOf;

    // 账户消费记录
    mapping (address => mapping (address => uint256)) internal allowed;

    constructor(string memory _token_name, string memory _token_symbol, uint8 _token_decimals, uint256 _total) public {
        _name = _token_name;
        _symbol = _token_symbol;
        _decimals = _token_decimals;
        uint256 pow = 10 ** uint256(_decimals);
        _totalSupply = _total.mul(pow);
        _balanceOf[msg.sender] = _totalSupply;
    }

    // 代币名称
    function name() public override view returns (string memory) {
        return _name;
    }

    // 代币缩写--符号
    function symbol() public override view returns (string memory) {
        return _symbol;
    }

    // 代币小数位数
    function decimals() public override view returns (uint8) {
        return _decimals;
    }

    // 代币总数
    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }

    // 账户余额
    function balanceOf(address _addr) public override view returns (uint256) {
        return _balanceOf[_addr];
    }

    // 从发起帐户转账到指定账户
    function transfer(address _to, uint256 _value) public override transferAllowed(msg.sender) returns (bool) {
        return _transfer(msg.sender, _to, _value);
    }

    // 从指定账户转出金额
    function transferFrom(address _from, address _to, uint256 _value) public override transferAllowed(_from) returns (bool) {
        require(_value <= allowed[_from][msg.sender]);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        return _transfer(_from, _to, _value);
    }

    function _transfer(address _from, address _to, uint256 _value) internal returns (bool) {
        require(_to != address(0));
        require(_value > 0);
        require(_value <= _balanceOf[_from]);

        _balanceOf[_from] = _balanceOf[_from].sub(_value);
        _balanceOf[_to] = _balanceOf[_to].add(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    // 给地址授权金额
    function approve(address _spender, uint256 _value) external override returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) external override view returns (uint256) {
        return allowed[_owner][_spender];
    }

}
