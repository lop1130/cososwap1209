pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
// SPDX-License-Identifier: MIT

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "e0");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "e1");
        }
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() internal {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "e3");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ow1");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ow2");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "e4");
        (bool success, bytes memory returndata) = target.call{value : weiValue}(data);
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "e5");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "e6");
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "e7");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "e8");
        uint256 c = a / b;
        return c;
    }
}

interface IERC721Enumerable {
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function mintForMiner(address _to) external returns (bool, uint256);

    function MinerList(address _address) external returns (bool);
}

contract IGOPool is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;
    address payable public feeAddress;
    address payable public teamAddress;
    address public IGOPoolFactory;
    mapping(address => mapping(uint256 => bool)) public CanBuyBackList;
    mapping(address => uint256[]) public UserIgoTokenIdList;
    mapping(address => uint256) public UserIgoTokenIdListNum;
    mapping(uint256 => tokenIdInfo) public TokenIdSwapStatusStatusList;
    mapping(address => uint256[]) public userStakingTokenIdList;
    mapping(address => uint256) public userStakingNumList;
    mapping(address => bool) public whiteList;

    struct nftInfo {
        string name;
        string symbol;
        string tokenURI;
        address ownerOf;
        tokenIdInfo statusList;
    }

    struct tokenIdInfo {
        bool mintStatus;
        bool buybackStatus;
        bool swapStatus;
    }

    struct orderItem_1 {
        uint256 orderId;
        IERC721Enumerable nftToken;
        uint256 igoTotalAmount;
        address erc20Token;
        uint256 price;
        bool orderStatus;
        uint256 igoOkAmount;
        uint256 startBlock;
        uint256 endBlock;
        uint256 cosoQuote;
    }

    struct orderItem_2 {
        IERC20 swapToken;
        uint256 swapPrice;
        uint256 buyBackEndBlock;
        uint256 buyBackNum;
        uint256 swapFee;
        uint256 igoMaxAmount;
        address blackHoleAddress;
        IERC721Enumerable CosoNFT;
        bool useStakingCoso;
        bool useWhiteList;
        IERC20 ETH;
    }

    orderItem_1 public fk1;
    orderItem_2 public fk2;

    constructor(IERC721Enumerable _Coso, address _feeAddress, address _teamAddress, IERC20 _ETH, uint256 orderId, IERC721Enumerable _nftToken, uint256 _igoAmount, address _erc20Token, uint256 _price, uint256 _swapRate) public {
        IGOPoolFactory = msg.sender;
        feeAddress = payable(_feeAddress);
        teamAddress = payable(_teamAddress);
        fk2.CosoNFT = _Coso;
        fk2.ETH = _ETH;
        fk1.cosoQuote = 1;
        fk1.orderId = orderId;
        fk1.orderStatus = true;
        fk1.nftToken = _nftToken;
        fk1.igoTotalAmount = _igoAmount;
        fk1.erc20Token = _erc20Token;
        fk1.price = _price;
        fk1.igoOkAmount = 0;
        fk2.swapFee = _swapRate;
        fk2.igoMaxAmount = 0;
        fk2.blackHoleAddress = 0x000000000000000000000000000000000000dEaD;
    }

    modifier onlyIGOPoolFactory() {
        require(msg.sender == IGOPoolFactory, "e00");
        _;
    }

    modifier onlyBeforeStartBlock() {
        require(block.number < fk1.startBlock || fk1.startBlock == 0, "e01");
        _;
    }

    function addWhiteList(address[] memory _addressList) external onlyOwner {
        //require(fk2.useWhiteList, "e02");
        for (uint256 i = 0; i < _addressList.length; i++) {
            require(_addressList[i] != address(0), "e03");
            whiteList[_addressList[i]] = true;
        }
    }

    function enableIgo() external onlyOwner {
        //require(!fk1.orderStatus, "e04");
        fk1.orderStatus = true;
    }

    function disableIgo() external onlyOwner {
        //require(fk1.orderStatus, "e05");
        fk1.orderStatus = false;
    }

    function setIgo(address payable _feeAddress, uint256 _fee, IERC721Enumerable _CosoNft) external onlyIGOPoolFactory onlyBeforeStartBlock {
        require(_feeAddress!=address(0) && _fee>0 && address(_CosoNft) != address(0));
        feeAddress = _feeAddress;
        fk2.swapFee = _fee;
        fk2.CosoNFT = _CosoNft;
    }

    function setTeamAddress(address payable _teamAddress) external onlyOwner {
        require(_teamAddress != address(0), "e01");
        teamAddress = _teamAddress;
    }

    function setIgoTotalAmount(uint256 _igoTotalAmount) external onlyOwner {
        fk1.igoTotalAmount = _igoTotalAmount;
    }

    function setTaskType(uint256 _igoMaxAmount, bool _useWhiteList, bool _useStakingCoso, uint256 _CosoQuote) external onlyOwner onlyBeforeStartBlock {
        fk2.igoMaxAmount = _igoMaxAmount;
        fk2.useWhiteList = _useWhiteList;
        fk2.useStakingCoso = _useStakingCoso;
        fk1.cosoQuote = _CosoQuote;
    }

    function setSwapTokenPrice(IERC20 _swapToken, uint256 _swapPrice) external onlyOwner {
        require(block.number <= fk1.endBlock || address(fk2.swapToken) == address(0), "e06");
        fk2.swapToken = _swapToken;
        fk2.swapPrice = _swapPrice;
    }

    function setTimeLines(uint256 _startBlock, uint256 _endBlock, uint256 _buyBackEndBlock) external onlyOwner {
        require(_buyBackEndBlock > _endBlock && _endBlock > _startBlock, "e07");
        fk1.startBlock = _startBlock;
        fk1.endBlock = _endBlock;
        fk2.buyBackEndBlock = _buyBackEndBlock;
    }

    function stakingCoso(uint256[] memory _tokenIdList) external {
        require(fk2.useStakingCoso, "e08");
        require(block.number < fk1.startBlock, "e09");
        if (fk2.igoMaxAmount > 0) {
            require(userStakingNumList[msg.sender].add(_tokenIdList.length.mul(fk1.cosoQuote)) <= fk2.igoMaxAmount, "e10");
        }
        for (uint i = 0; i < _tokenIdList.length; i++) {
            fk2.CosoNFT.transferFrom(msg.sender, address(this), _tokenIdList[i]);
            userStakingTokenIdList[msg.sender].push(_tokenIdList[i]);
        }
        userStakingNumList[msg.sender] = userStakingNumList[msg.sender].add(_tokenIdList.length.mul(fk1.cosoQuote));
    }

    function withdrawCoso() external {
        require(block.number > fk1.endBlock, "e11");
        uint256[] memory userCosoList = userStakingTokenIdList[msg.sender];
        require(userCosoList.length > 0, "e12");
        for (uint i = 0; i < userCosoList.length; i++) {
            fk2.CosoNFT.transferFrom(address(this), msg.sender, userCosoList[i]);
        }
        delete userStakingTokenIdList[msg.sender];
        delete userStakingNumList[msg.sender];
    }

    function igo(uint256 idoNum) external payable nonReentrant {
        require(idoNum > 0, "e13");
        require(fk1.nftToken.MinerList(address(this)), "e14");
        require(fk1.orderStatus, "e15");
        require(block.number >= fk1.startBlock && block.number <= fk1.endBlock, "e16");
        require(fk1.igoOkAmount.add(idoNum) <= fk1.igoTotalAmount, "e17");
        if (fk2.igoMaxAmount > 0) {
            require(UserIgoTokenIdListNum[msg.sender].add(idoNum) <= fk2.igoMaxAmount, "e18");
        }
        if (fk2.useStakingCoso) {
            require(idoNum <= userStakingNumList[msg.sender], "e19");
        }
        if (fk2.useWhiteList) {
            require(whiteList[msg.sender], "e20");
        }
        uint256 allAmount = (fk1.price).mul(idoNum);
        uint256 fee = allAmount.mul(fk2.swapFee).div(100);
        uint256 toTeam = allAmount.sub(fee);
        if (fk1.erc20Token == address(0)) {
            require(msg.value == allAmount, "e21");
            teamAddress.transfer(toTeam);
            feeAddress.transfer(fee);
        } else {
            require(IERC20(fk1.erc20Token).balanceOf(msg.sender) >= allAmount, "e22");
            IERC20(fk1.erc20Token).safeTransferFrom(msg.sender, teamAddress, toTeam);
            IERC20(fk1.erc20Token).safeTransferFrom(msg.sender, feeAddress, fee);
        }
        for (uint256 i = 0; i < idoNum; i++) {
            (,uint256 _token_id) = fk1.nftToken.mintForMiner(msg.sender);
            TokenIdSwapStatusStatusList[_token_id].mintStatus = true;
            CanBuyBackList[msg.sender][_token_id] = true;
            UserIgoTokenIdList[msg.sender].push(_token_id);
            fk1.igoOkAmount = fk1.igoOkAmount.add(1);
            UserIgoTokenIdListNum[msg.sender] = UserIgoTokenIdListNum[msg.sender].add(1);
            if (fk2.useStakingCoso) {
                userStakingNumList[msg.sender] = userStakingNumList[msg.sender].sub(1);
            }
        }
    }

    function swapToken(uint256 _tokenId) external nonReentrant {
        require(block.number > fk1.startBlock, "e23");
        require(address(fk2.swapToken) != address(0), "e24");
        uint256 allAmount = fk2.swapPrice;
        fk1.nftToken.transferFrom(msg.sender, fk2.blackHoleAddress, _tokenId);
        if (CanBuyBackList[msg.sender][_tokenId]) {
            CanBuyBackList[msg.sender][_tokenId] = false;
            fk2.buyBackNum = fk2.buyBackNum.add(1);
        }
        TokenIdSwapStatusStatusList[_tokenId].swapStatus = true;
        require(fk2.swapToken.balanceOf(address(this)) >= allAmount, "e25");
        fk2.swapToken.safeTransfer(msg.sender, allAmount);
    }

    function buyback(uint256[] memory _tokenIdList) external nonReentrant {
        require(block.number > fk1.endBlock && block.number < fk2.buyBackEndBlock, "e26");
        uint256 buybackNum = _tokenIdList.length;
        uint256 leftrate = uint256(100).sub(fk2.swapFee);
        uint256 allAmount = (fk1.price).mul(leftrate).mul(buybackNum).div(100);
        for (uint256 i = 0; i < _tokenIdList.length; i++) {
            require(CanBuyBackList[msg.sender][_tokenIdList[i]], "e27");
        }
        for (uint256 i = 0; i < _tokenIdList.length; i++) {
            fk1.nftToken.transferFrom(msg.sender, fk2.blackHoleAddress, _tokenIdList[i]);
            CanBuyBackList[msg.sender][_tokenIdList[i]] = false;
            fk2.buyBackNum = fk2.buyBackNum.add(1);
            TokenIdSwapStatusStatusList[_tokenIdList[i]].buybackStatus = true;
        }
        if (fk1.erc20Token != address(0)) {
            IERC20(fk1.erc20Token).safeTransfer(msg.sender, allAmount);
        } else {
            msg.sender.transfer(allAmount);
        }
    }

    function takeTokens(address _token, uint256 _amount) external onlyOwner returns (bool){
        if (_token == address(0) && address(this).balance > 0) {
            msg.sender.transfer(address(this).balance);
            return true;
        } else if (_token != address(0) && IERC20(_token).balanceOf(address(this)) > 0) {
            IERC20(_token).safeTransfer(msg.sender, _amount);
            return true;
        } else {
            return false;
        }
    }

    function getTimeStatus(uint256 _time) external view returns (bool canStaking, bool canIgo, bool canBuyBack, bool canWithDraw, bool canSwapToken) {
        if (_time < fk1.startBlock) {
            return (true, false, false, false, false);
        } else if (fk1.startBlock <= _time && _time <= fk1.endBlock) {
            return (false, true, false, false, true);
        } else if (fk1.endBlock < _time && _time <= fk2.buyBackEndBlock) {
            return (false, false, true, true, true);
        } else if (_time > fk2.buyBackEndBlock) {
            return (false, false, false, true, true);
        }
    }

    function getTokenInfoByIndex() external view returns (orderItem_1 memory orderItem1, orderItem_2 memory orderItem2, string memory name2, string memory symbol2, uint256 decimals2, uint256 price2, string memory nftName, string memory nftSymbol){
        orderItem1 = fk1;
        orderItem2 = fk2;
        if (orderItem1.erc20Token == address(0)) {
            name2 = fk2.ETH.name();
            symbol2 = fk2.ETH.symbol();
            decimals2 = fk2.ETH.decimals();
        } else {
            name2 = IERC20(orderItem1.erc20Token).name();
            symbol2 = IERC20(orderItem1.erc20Token).symbol();
            decimals2 = IERC20(orderItem1.erc20Token).decimals();
        }
        price2 = orderItem1.price.mul(1e18).div(10 ** decimals2);
        nftName = orderItem1.nftToken.name();
        nftSymbol = orderItem1.nftToken.symbol();
    }

    function getUserIdoTokenIdList(address _address) external view returns (uint256[] memory) {
        return UserIgoTokenIdList[_address];
    }

    function getNftInfo(IERC721Enumerable _nftToken, uint256 _tokenId) public view returns (nftInfo memory nftInfo2) {
        nftInfo2 = nftInfo(_nftToken.name(), _nftToken.symbol(), _nftToken.tokenURI(_tokenId), _nftToken.ownerOf(_tokenId), TokenIdSwapStatusStatusList[_tokenId]);
    }

    function massGetNftInfo(IERC721Enumerable _nftToken, uint256[] memory _tokenIdList) public view returns (nftInfo[] memory nftInfolist2) {
        nftInfolist2 = new nftInfo[](_tokenIdList.length);
        for (uint256 i = 0; i < _tokenIdList.length; i++) {
            nftInfolist2[i] = getNftInfo(_nftToken, _tokenIdList[i]);
        }
    }

    function getStaking(address _user) external view returns (uint256[] memory idTokenList, uint256 idTokenListNum, nftInfo[] memory nftInfolist2, uint256 igoQuota, uint256 maxIgoNum) {
        idTokenList = userStakingTokenIdList[_user];
        idTokenListNum = idTokenList.length;
        nftInfolist2 = massGetNftInfo(fk2.CosoNFT, idTokenList);
        igoQuota = userStakingNumList[_user];
        maxIgoNum = fk2.igoMaxAmount;
    }

    receive() payable external {}
}

contract IGOPoolFactory is Ownable {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;
    uint256 public orderNum = 0;
    uint256 public swapRate = 10;
    address public feeAddress;
    IERC20 public ETH;
    IERC721Enumerable public CosoNFT;
    mapping(uint256 => IGOPool) public orderItemInfo;
    mapping(IGOPool => uint256) public orderItemInfo2;
    mapping(IERC721Enumerable => uint256[]) public nftAddressOrderIdList;
    mapping(IERC721Enumerable => IGOPool[]) public nftAddressPoolList;
    mapping(address => bool) public erc20tokenWhiteList;
    mapping(address => bool) public igoWhiteList;

    struct tokenIdInfo {
        uint256 poolId;
        bool mintStatus;
        bool buybackStatus;
        bool swapStatus;
    }

    struct tokenIdInfoList {
        tokenIdInfo[] tokenIdInfoListItem;
    }

    struct orderItem_1 {
        uint256 orderId;
        IERC721Enumerable nftToken;
        uint256 igoTotalAmount;
        address erc20Token;
        uint256 price;
        bool orderStatus;
        uint256 igoOkAmount;
        uint256 startBlock;
        uint256 endBlock;
        uint256 cosoQuote;
    }

    struct orderItem_2 {
        IERC20 swapToken;
        uint256 swapPrice;
        uint256 buyBackEndBlock;
        uint256 buyBackNum;
        uint256 swapFee;
        uint256 igoMaxAmount;
        address blackHoleAddress;
        IERC721Enumerable CosoNFT;
        bool useStakingCoso;
        bool useWhiteList;
        IERC20 ETH;
    }

    struct orderItem_3 {
        orderItem_1 x1;
        orderItem_2 x2;
        string name2;
        string symbol2;
        uint256 decimals2;
        uint256 price2;
        string nftName;
        string nftSymbol;
        IGOPool igoAddress;
    }

    event createIgoEvent(IGOPool _igoAddress, IERC721Enumerable _Coso, address _feeAddress, address _teamAddress, IERC20 _ETH, uint256 _orderId, IERC721Enumerable _nftToken, uint256 _igoTotalAmount, address _erc20Token, uint256 _price, uint256 _swapRate);

    constructor(IERC721Enumerable _CosoNft, IERC20 _ETH, address _feeAddress) public {
        require(address(_CosoNft) != address(0) && address(_ETH) != address(0) && _feeAddress != address(0), "e01");
        CosoNFT = _CosoNft;
        ETH = _ETH;
        feeAddress = _feeAddress;
        addIgoWhiteList(msg.sender);
        addErc20tokenWhiteList(address(0));
    }

    function addErc20tokenWhiteList(address _address) public onlyOwner {
        erc20tokenWhiteList[_address] = true;
    }

    function removeErc20tokenWhiteList(address _address) external onlyOwner {
        erc20tokenWhiteList[_address] = false;
    }

    function addIgoWhiteList(address _address) public onlyOwner {
        require(_address != address(0), "e02");
        igoWhiteList[_address] = true;
    }

    function removeIgoWhiteList(address _address) external onlyOwner {
        require(_address != address(0), "e03");
        igoWhiteList[_address] = false;
    }

    function setFeeAddress(address _feeAddress, uint256 _swapRate) external onlyOwner {
        require(_feeAddress != address(0), "e04");
        feeAddress = _feeAddress;
        swapRate = _swapRate;
    }

    function createIGO(address _teamAddress, IERC721Enumerable _nftToken, uint256 _igoTotalAmount, address _erc20Token, uint256 _price) external {
        require(igoWhiteList[msg.sender], "e05");
        require(erc20tokenWhiteList[_erc20Token], "e06");
        IGOPool igoitem = new IGOPool(CosoNFT, feeAddress, _teamAddress, ETH, orderNum, _nftToken, _igoTotalAmount, _erc20Token, _price, swapRate);
        emit createIgoEvent(igoitem, CosoNFT, feeAddress, _teamAddress, ETH, orderNum, _nftToken, _igoTotalAmount, _erc20Token, _price, swapRate);
        orderItemInfo[orderNum] = igoitem;
        orderItemInfo2[igoitem] = orderNum;
        nftAddressOrderIdList[_nftToken].push(orderNum);
        nftAddressPoolList[_nftToken].push(igoitem);
        orderNum = orderNum.add(1);
        igoitem.transferOwnership(msg.sender);
    }

    function setIgo(IGOPool _igo, address payable _feeAddress, uint256 _fee, IERC721Enumerable _CosoNft) external onlyOwner {
        _igo.setIgo(_feeAddress, _fee, _CosoNft);
    }

    function takeErc20Token(IERC20 _token) external onlyOwner {
        uint256 amount = _token.balanceOf(address(this));
        require(amount > 0, "e07");
        _token.safeTransfer(msg.sender, amount);
    }

    function getTokenIdStatusList(IERC721Enumerable _nftToken, uint256 _tokenId) public view returns (tokenIdInfo[] memory x) {
        uint256[] memory index_list = nftAddressOrderIdList[_nftToken];
        x = new tokenIdInfo[](index_list.length);
        for (uint256 i = 0; i < index_list.length; i++) {
            (bool mintStatus,bool buybackStatus,bool swapStatus) = orderItemInfo[index_list[i]].TokenIdSwapStatusStatusList(_tokenId);
            x[i] = tokenIdInfo(index_list[i], mintStatus, buybackStatus, swapStatus);
        }
    }

    function massGetTokenIdStatusList(IERC721Enumerable _nftToken, uint256[] memory _tokenIdList) external view returns (tokenIdInfoList[] memory x) {
        x = new tokenIdInfoList[](_tokenIdList.length);
        for (uint256 i = 0; i < _tokenIdList.length; i++) {
            x[i] = tokenIdInfoList(getTokenIdStatusList(_nftToken, _tokenIdList[i]));
        }
        return x;
    }

    function getIgoInfo(uint256 _index) public view returns (orderItem_3 memory returnIgoInfo) {
        returnIgoInfo.igoAddress = orderItemInfo[_index];
        {
            (uint256 orderId,
            IERC721Enumerable nftToken,
            uint256 igoAmount,
            address erc20Token,
            uint256 price,
            bool orderStatus,
            uint256 hasigoAmount,
            uint256 startBlock,
            uint256 endBlock,uint256 cosoQuote) = orderItemInfo[_index].fk1();
            returnIgoInfo.x1 = orderItem_1(orderId, nftToken, igoAmount, erc20Token, price, orderStatus, hasigoAmount, startBlock, endBlock, cosoQuote);
        }
        {
            (IERC20 swapToken,
            uint256 swapPrice,
            uint256 GetRewardBlockNum,
            uint256 BuyBackNum,
            uint256 swapFee,
            uint256 maxIgoAmount,address blackholeaddress,IERC721Enumerable CosoNFT2, bool useStakingCoso,
            bool useWhiteList, IERC20 ETH2) = orderItemInfo[_index].fk2();
            returnIgoInfo.x2 = orderItem_2(swapToken, swapPrice, GetRewardBlockNum, BuyBackNum, swapFee, maxIgoAmount, blackholeaddress, CosoNFT2, useStakingCoso, useWhiteList, ETH2);
        }
        {
            (,,string memory name2, string memory symbol2, uint256 decimals2, uint256 price2,string memory nftName,string memory nftSymbol) = orderItemInfo[_index].getTokenInfoByIndex();
            returnIgoInfo.name2 = name2;
            returnIgoInfo.symbol2 = symbol2;
            returnIgoInfo.decimals2 = decimals2;
            returnIgoInfo.price2 = price2;
            returnIgoInfo.nftName = nftName;
            returnIgoInfo.nftSymbol = nftSymbol;
        }
    }

    function massGetIgoInfo(uint256[] memory index_list) public view returns (orderItem_3[] memory returnIgoInfoList) {
        returnIgoInfoList = new orderItem_3[](index_list.length);
        for (uint256 i = 0; i < index_list.length; i++) {
            returnIgoInfoList[i] = getIgoInfo(index_list[i]);
        }
    }

    function getNftAddressPoolList(IERC721Enumerable _nftToken) external view returns (IGOPool[] memory IGOPoolList, orderItem_3[] memory returnIgoInfoList) {
        IGOPoolList = nftAddressPoolList[_nftToken];
        uint256[] memory indexList = new uint256[](IGOPoolList.length);
        for (uint256 i = 0; i < IGOPoolList.length; i++) {
            indexList[i] = orderItemInfo2[IGOPoolList[i]];
        }
        returnIgoInfoList = massGetIgoInfo(indexList);
    }
}