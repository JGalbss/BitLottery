//An NFT Lottery Contract by Josh Galbreath
//Signed by 8Bit Team
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BitLottery is ERC721Enumerable, Ownable, VRFConsumerBaseV2 {
  
  using SafeMath for uint256;
  using Strings for uint256;
  //
  mapping(uint256 => address) private _owners;

  // Mapping owner address to token count
  mapping(address => uint256) private _balances;

  // Mapping from token ID to approved address
  mapping(uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  // chainlink
  VRFCoordinatorV2Interface COORDINATOR;
  LinkTokenInterface LINKTOKEN;

  uint64 s_subscriptionId = 1827;
  address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
  address link = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;
  bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
  uint32 callbackGasLimit = 100000;
  uint16 requestConfirmations = 3;
  uint32 numWords =  1;
  uint256 public s_winnerid;
  uint256 public s_requestId;
  address s_owner;
  uint256 internal fee;

  // nft implementation

  string baseURI;
  string public baseExtension = ".json";
  uint256 public cost = 0.000 ether;
  uint256 public maxSupply = 2;
  uint256 public maxMintAmount = 2;
  bool public revealed = true;
  string public notRevealedUri;

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI,
    string memory _initNotRevealedUri,
    uint64 subscriptionId
  ) ERC721(_name, _symbol) VRFConsumerBaseV2(vrfCoordinator) {
    setBaseURI(_initBaseURI);
    setNotRevealedURI(_initNotRevealedUri);
    COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    LINKTOKEN = LinkTokenInterface(link);
    s_owner = msg.sender;
    s_subscriptionId = subscriptionId;
  }

  // internal

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  // public

  // get winner ticket id!
  
  function requestRandomWords() public onlyOwner {
    // Will revert if subscription is not set and funded.
      s_requestId = COORDINATOR.requestRandomWords(
      keyHash,
      s_subscriptionId,
      requestConfirmations,
      callbackGasLimit,
      numWords
    );
  }

  //fulfill random number request with value modifier, pays winner
  function fulfillRandomWords(
    uint256, /* requestId */
    uint256[] memory randomNumber
  ) internal override{
    s_winnerid = randomNumber[0].mod(1000).add(1);
    withdraw();
  }

  function mint(uint256 _mintAmount) public payable {
    uint256 supply = totalSupply();
    require(_mintAmount > 0);
    require(_mintAmount <= maxMintAmount);
    require(supply + _mintAmount <= maxSupply);
    if (supply + _mintAmount == maxSupply) {
      requestRandomWords();
    }

    if (msg.sender != owner()) {
      require(msg.value >= cost * _mintAmount);
    }

    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply + i);
      _owners[supply + i] = msg.sender;
    }
  }
  // owner of function
  function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
  }
  
  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    
    if(revealed == false) {
        return notRevealedUri;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
  }

  // only owner
  
  function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
    notRevealedUri = _notRevealedURI;
  }

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

  //pay to winning wallet and development team
 
  function withdraw() public payable {
      uint256 supply = totalSupply();
      require(supply == maxSupply);
      (bool hs, ) = payable(0xC233570Bd09527C54ec14f13bEfFe2845F76d2a5).call{value: address(this).balance * 10 / 100}("");
      require(hs);
      // =============================================================================

      (bool os, ) = payable(ownerOf(s_winnerid)).call{value: address(this).balance}("");
      require(os);
      // =============================================================================
  }
}
