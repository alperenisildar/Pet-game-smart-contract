pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract PetCreator is ERC721, Ownable{

    event NewPet(uint petId, string name);
    
    struct Pet{
        string name;            //pet name
        uint256 id;             //pet id
        uint32 level;           //pet level (starts from 1kg)
        uint foodInStomach;     //how many foods in the pet's stomach
        uint stomachSize;       //pet stomach size (starts from 2)
        uint lastFeedingTime;   //pet's last feeding time
        uint readyToFood;       //pet's feeding frequency (in hours)
        uint endurance;         //pet's endurance (it will die if you won't feed it for endurance)
    }

    uint256 nextId = 0;
    uint poopCountToNewPet;
    uint newPetFee;

    Pet[] public allPets;
    mapping (uint => address) petToOwner;
    mapping (address => uint) ownerToPoopCount;
    mapping (uint256 => Pet) tokenDetails;

    constructor (string memory name, string memory symbol) ERC721(name, symbol){ 
        poopCountToNewPet = 100;
        newPetFee = 0.02 ether;
    }
    
    //new pet function
    function mint(string memory _name) public payable onlyOwner{
        require(msg.value == newPetFee);
        tokenDetails[nextId] = Pet(_name, nextId, 1, 0, 2, block.timestamp, 0 hours, 4 hours);
        allPets.push(tokenDetails[nextId]);
        petToOwner[nextId] = msg.sender;
        emit NewPet(nextId, _name);
        _safeMint(msg.sender, nextId);
        nextId++;
    }

    //feeding the pet
    function feedPet(uint256 petId) public {
        require(isDead(petId), "<<< YOUR PET HAS DIED >>>");
        require(isReadyToFeed(petId), "I'm not hungry!");
        require(allPets[petId].stomachSize > allPets[petId].foodInStomach, "I'm full!");
        _triggerFeedingCooldown(petId);
        allPets[petId].foodInStomach++;
    }

    //pooping the pet(if it can)
    function petPoop(uint256 petId) external { 
        require(allPets[petId].foodInStomach >= allPets[petId].stomachSize / 2, "I'm still hungry for poop");
        ownerToPoopCount[msg.sender]++;
        allPets[petId].foodInStomach -= allPets[petId].stomachSize / 2;
    }
    
    //a baby pet made by poops
    function newPetFromPoop() public onlyOwner{
        require(ownerToPoopCount[msg.sender] >= poopCountToNewPet, "<<< YOU DONT HAVE ENOUGH POOPS >>>");
        ownerToPoopCount[msg.sender] -= poopCountToNewPet;
        allPets.push(Pet("no_name", nextId, 1, 0, 2, block.timestamp, 0 hours, 4 hours));
        petToOwner[nextId] = msg.sender;
        nextId++;
    }
    
    //pet level up (if it can)
    function levelUp(uint256 petId) public {
        Pet storage curr = allPets[petId];
        require(curr.foodInStomach == curr.stomachSize, "I'm not ready for growing up");
        curr.level++;
        curr.foodInStomach = 0;
        curr.stomachSize *= 2;
        curr.endurance += 2 hours;
    }

    //selling a pet to another person
    function sellPet(uint256 petId, address _to) public onlyOwner{
        require(petToOwner[petId] == msg.sender, "<<< YOU ARE NOT THE OWNER OF THIS PET >>>");
        petToOwner[petId] = _to;
        _safeTransfer(msg.sender, _to, petId, "");
    }

    //selling poop to another person
    function sellPoop(uint poopToSell, address to) public onlyOwner{
        require(poopToSell <= ownerToPoopCount[msg.sender], "<<< YOU HAVE NOT ENOUGH POOPS");
        ownerToPoopCount[msg.sender] -= poopToSell;
        ownerToPoopCount[to] += poopToSell;
    }

    //setting the name of the baby pet (made by poops, if it has already a name)
    function setName(uint256 petId, string memory _name) public onlyOwner {
        require(petToOwner[petId] == msg.sender, "<<< YOU ARE NOT THE OWNER OF THIS PET >>>");
        require(stringsEquals(allPets[petId].name, "no_name"), "I have already a name");
        allPets[petId].name = _name;
    }

    //triggeering the available feeding time for the current pet (calculated based on its level)
    function _triggerFeedingCooldown(uint256 petId) private {
        uint cooldownTime = allPets[petId].level * 10 minutes;
        allPets[petId].readyToFood = uint(block.timestamp + cooldownTime);
    }

    //is the pet ready for the next meal?
    function isReadyToFeed(uint256 petId) private view returns (bool) {
        return (allPets[petId].readyToFood <= block.timestamp);
    }

    //  😞🥺😞
    function isDead(uint256 petId) private view returns(bool) {
        Pet storage curr = allPets[petId];
        return (curr.lastFeedingTime + curr.endurance > block.timestamp);
    } 

    //helper function for new addressings
    function _beforeTokenTransfer (address from, address to, uint256 tokenId) view internal override {
        require(isDead(tokenId));
    }
    
    //helper function for checking equality of 2 strings
    function stringsEquals(string memory s1, string memory s2) private pure returns (bool) {
        bytes memory b1 = bytes(s1);
        bytes memory b2 = bytes(s2);
        uint256 l1 = b1.length;
        if (l1 != b2.length) return false;
        for (uint256 i=0; i<l1; i++) {
            if (b1[i] != b2[i]) return false;
        }
        return true;
    }
}
