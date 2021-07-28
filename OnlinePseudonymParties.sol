contract OnlinePseudonymParties {   
    
    bool public borderSetting;

    uint constant public period = 4 weeks;
    uint constant genesis = 198000;
    mapping (uint => uint) public hour;
    
    function schedule() public view returns(uint) { return ((block.timestamp - genesis) / period); }
    function toSeconds(uint _t) public pure returns (uint) { return genesis + _t * period; }
    function halftime(uint _t) public view returns (bool) { return((block.timestamp > toSeconds(_t)+period/2)); }

    function computeHour(uint _t) public { hour[_t] =  1 + uint(keccak256(abi.encode(_t)))%24; }
    function pseudonymEvent(uint _t) public returns (uint) { if(hour[_t] == 0) computeHour(_t); return toSeconds(_t) + hour[_t]*1 hours; }

    uint entropy;

    mapping (uint => mapping (address => bytes32)) public commit;
    mapping (uint => mapping (uint => uint)) public generator;
    mapping (uint => mapping (uint => uint)) public points;
    mapping (uint => uint) public leader;

    enum Status { Inactive, Commit, Party }
    
    struct Nym { uint id; Status status; }
    struct Pair { bool[2] verified; bool disputed; }
    struct Court { uint id; bool[2] verified; }

    mapping (uint => mapping (address => Nym)) public nym;
    mapping (uint => address[]) public shuffler;
    mapping (uint => uint) public shuffled;
    mapping (uint => mapping (uint => Pair)) public pair;
    mapping (uint => mapping (address => Court)) public court;
    mapping (uint => mapping (uint => address)) public courtIndex;
    mapping (uint => uint) public immigrants;

    mapping (uint => uint) public population;
    mapping (uint => mapping (address => bool)) public proofOfUniqueHuman;

    enum Token { Personhood, Registration, Immigration } 

    mapping (uint => mapping (Token => mapping (address => uint))) public balanceOf;
    mapping (uint => mapping (Token => mapping (address => mapping (address => uint)))) public allowed;

    function registered(uint _t) public view returns (uint) { return shuffler[_t].length; }
    function pairs(uint _t) public view returns (uint) { return (registered(_t)/2); }
    function deductToken(Token _token, uint _t) internal { require(balanceOf[_t][_token][msg.sender] >= 1); balanceOf[_t][_token][msg.sender]--; }
    function pairVerified(uint _t, uint _pair) public view returns (bool) { return (pair[_t][_pair].verified[0] == true && pair[_t][_pair].verified[1] == true); }
    function getPair(uint _id) public pure returns (uint) { return (_id+1)/2; }
    function getCourt(uint _t, uint _court) public view returns (uint) { require(_court != 0); return 1+(_court-1)%pairs(_t); }

    function register(bytes32 _commit) external {
        uint t = schedule();
        require(!halftime(t));
        deductToken(Token.Registration, t);
        shuffler[t].push(msg.sender);
        commit[t][msg.sender] = _commit;
        nym[t][msg.sender].status = Status.Commit;
    }
    function immigrate() external {
        uint t = schedule();
        require(!halftime(t));
        deductToken(Token.Immigration, t);
        immigrants[t]++;
        court[t][msg.sender].id = immigrants[t];
        courtIndex[t][immigrants[t]] = msg.sender;
    }
    function shuffle() external {
        uint t = schedule()-1;
        uint _shuffled = shuffled[t];
        if(_shuffled == 0) entropy = generator[t][leader[t]];
        uint unshuffled = registered(t) -_shuffled;
        if(unshuffled > 0) {
            uint randomNumber = entropy % unshuffled;
            entropy ^= uint160(shuffler[t][randomNumber]);
            (shuffler[t][unshuffled-1], shuffler[t][randomNumber]) = (shuffler[t][randomNumber], shuffler[t][unshuffled-1]);
            nym[t][shuffler[t][unshuffled-1]].id = unshuffled;
            shuffled[t]++;
        }
    }
    function reveal(uint _entropy) external {
        uint t = schedule()-1;
        require(halftime(t+1));
        uint id = nym[t][msg.sender].id;
        require(id != 0);
        require(nym[t][msg.sender].status == Status.Commit);
        require(keccak256(abi.encode(_entropy)) == commit[t][msg.sender]);
        uint vote = ((_entropy%pairs(t)) + id)%pairs(t);
        generator[t][vote] ^= _entropy;
        points[t][vote]++;
        if(points[t][vote] > points[t][leader[t]]) leader[t] = vote;
        nym[t][msg.sender].status = Status.Party;
    }

    function verify() external {
        uint t = schedule()-2;
        require(block.timestamp > pseudonymEvent(t+2));
        require(nym[t][msg.sender].status == Status.Party);
        uint id = nym[t][msg.sender].id;
        require(id != 0);
        require(pair[t][getPair(id)].disputed == false);
        pair[t][getPair(id)].verified[id%2] = true;
    }
    function judge(address _account) external {
        uint t = schedule()-2;
        require(block.timestamp > pseudonymEvent(t+2));
        uint signer = nym[t][msg.sender].id;
        require(getCourt(t, court[t][_account].id) == getPair(signer));
        court[t][_account].verified[signer%2] = true;
    }

    function allocateTokens(uint _t, uint _pair) internal {
        require(pairVerified(_t-2, _pair));
        balanceOf[_t][Token.Personhood][msg.sender]++;
        balanceOf[_t][Token.Registration][msg.sender]++;
        if(borderSetting == false) balanceOf[_t][Token.Immigration][msg.sender]++;
    }
    function completeVerification() external {
        uint t = schedule()-2;
        require(nym[t][msg.sender].status != Status.Inactive);
        uint id = nym[t][msg.sender].id;
        allocateTokens(t+2, getPair(id));
        nym[t][msg.sender].status = Status.Inactive;
    }
    function courtVerdict() external {
        uint t = schedule()-2;
        require(court[t][msg.sender].verified[0] == true && court[t][msg.sender].verified[1] == true);
        allocateTokens(t+2, getCourt(t, court[t][msg.sender].id));
        delete court[t][msg.sender];
    }        
    function claimPersonhood() external {
        uint t = schedule();
        deductToken(Token.Personhood, t);
        proofOfUniqueHuman[t][msg.sender] = true;
        population[t]++;
    }
    function invite() external {
        require(borderSetting == true);
        uint t = schedule();
        deductToken(Token.Registration, t);
        balanceOf[t][Token.Immigration][msg.sender]+=2;
    }
    
    function dispute() external {
        uint t = schedule()-2;
        uint id = nym[t][msg.sender].id;
        require(id != 0);
        require(!pairVerified(t, getPair(id)));
        pair[t][getPair(id)].disputed = true;
    }
    function assignCourt(uint _court, uint _t) internal {
        uint _pairs = pairs(_t);
        _court = 1+(_court-1)%_pairs;
        uint i = 0;
        while(courtIndex[_t][_court + _pairs*i] != address(0)) i++;
        court[_t][msg.sender].id = _court + _pairs*i;
        courtIndex[_t][_court + _pairs*i] = msg.sender;
    }
    function reassignNym() external {
        uint t = schedule()-2;
        uint id = nym[t][msg.sender].id;
        require(pair[t][getPair(id)].disputed == true);
        assignCourt(uint256(uint160(msg.sender)) + id, t);
        delete nym[t][msg.sender];
    }
    function reassignCourt() external {
        uint t = schedule()-2;
        uint id = court[t][msg.sender].id;
        uint _pair = getCourt(id, t);
        require(pair[t][_pair].disputed == true);
        delete court[t][msg.sender];
        assignCourt(1 + uint256(uint160(msg.sender)^uint160(shuffler[t][_pair*2])^uint160(shuffler[t][_pair*2-1])), t);
    }

    function _transfer(uint _t, address _from, address _to, uint _value, Token _token) internal { 
        require(balanceOf[_t][_token][_from] >= _value);
        balanceOf[_t][_token][_from] -= _value;
        balanceOf[_t][_token][_to] += _value;        
    }
    function transfer(address _to, uint _value, Token _token) external {
        _transfer(schedule(), msg.sender, _to, _value, _token);
    }
    function approve(address _spender, uint _value, Token _token) external {
        allowed[schedule()][_token][msg.sender][_spender] = _value;
    }
    function transferFrom(address _from, address _to, uint _value, Token _token) external {
        uint t = schedule();
        require(allowed[t][_token][_from][msg.sender] >= _value);
        _transfer(t, _from, _to, _value, _token);
        allowed[t][_token][_from][msg.sender] -= _value;
    }

    mapping (uint => mapping(address => bool)) public votedBorderSetting;
    mapping (uint => uint) public borderVoteCounter;
    
    function voteOnBorder() external {
        uint t = schedule()-1;
        require(proofOfUniqueHuman[t][msg.sender] == true);
        require(votedBorderSetting[t][msg.sender] == false);
        borderVoteCounter[t]++;
        votedBorderSetting[t][msg.sender] = true;
    }
    function changeBorderSetting() external {
        uint t = schedule()-1;
        require(borderVoteCounter[t] > population[t]/2);
        borderSetting = !borderSetting;
        delete borderVoteCounter[t];
    }
  
    function initialize(bytes32 _commit) external {
        uint t = schedule();
        require(pairs(t-2) == 0 && pairs(t) == 0);
        shuffler[t].push(msg.sender);
        commit[t][msg.sender] = _commit;
        nym[t][msg.sender].status = Status.Commit;
    }
}