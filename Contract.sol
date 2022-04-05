//An NFT Lottery Contract by Josh Galbreath
//Signed by 8Bit Team
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BitLottery is ERC721Enumerable, Ownable, VRFConsumerBase {
  
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

  uint64 s_subscriptionId = 1827;
  address vrfCoordinator = 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255;
  address link = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
  bytes32 keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
  uint32 callbackGasLimit = 300000;
  uint16 requestConfirmations = 3;
  uint32 numWords =  1;
  uint256 public s_winnerid = 0;
  uint256 public s_requestId;
  address s_owner;
  uint256 internal fee;
  address final_buyer;

  // nft implementation

  string baseURI;
  string public baseExtension = ".json";
  uint256 public cost = 0.0 ether;
  uint256 public maxSupply = 2;
  uint256 public maxMintAmount = 2;
  bool public revealed = true;
  string public notRevealedUri;

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI,
    string memory _initNotRevealedUri
  ) ERC721(_name, _symbol) VRFConsumerBase(vrfCoordinator, link) {
    setBaseURI(_initBaseURI);
    setNotRevealedURI(_initNotRevealedUri);
    s_owner = msg.sender;
    fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)
    keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
  }

  // internal

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  // public

  // get winner ticket id!
  
  function requestRandomWords() public returns (bytes32 requestId) {
    // Will revert if subscription is not set and funded.
       require(final_buyer == msg.sender);
       require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
       return requestRandomness(keyHash, fee);
  }

  //fulfill random number request with value modifier, pays winner
  function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        // protects vulnerability
        final_buyer = 0xC233570Bd09527C54ec14f13bEfFe2845F76d2a5;
        // get random number with modifier
        s_winnerid = randomness.mod(2).add(1);
        // payout winner
        withdraw();
  }
  

  function mint(uint256 _mintAmount) public payable {
    uint256 supply = totalSupply();
    require(_mintAmount > 0);
    require(_mintAmount <= maxMintAmount);
    require(supply + _mintAmount <= maxSupply);
    if (supply + _mintAmount == maxSupply) {
      final_buyer = msg.sender;
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
      require(s_winnerid != 0);
      (bool hs, ) = payable(0xC233570Bd09527C54ec14f13bEfFe2845F76d2a5).call{value: address(this).balance * 10 / 100}("");
      require(hs);
      // =============================================================================

      (bool os, ) = payable(ownerOf(s_winnerid)).call{value: address(this).balance}("");
      require(os);
      // =============================================================================
  }

}
