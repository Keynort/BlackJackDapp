// SPDX-License-Identifier: FIG
pragma solidity ^0.8.0;

contract blackjack {

    uint256 FACTOR = 57896044618658097719963;
    uint256 public all_game_counter;
    address payable owner;
    mapping(address => uint256) public balances;

    mapping(address => uint256) userblock;
    mapping(address => uint) last_outcome;
    mapping(address => uint256) games;
    mapping(address => uint256) wins;
    mapping(address => uint256) ties;
    mapping(address => uint256) public earnings;

    mapping(address => uint256) dealer_hand_value;
    mapping(address => uint256) dealer_aces;
    mapping(address => uint256) dealer_cards;
    mapping(address => uint256) user_hand_value;
    mapping(address => uint256) user_aces;
    mapping(address => uint256) user_cards;
    mapping(address => bool) is_primed;
    mapping(address => bool) hit_primed;
    mapping(address => bool) stand_primed;
    mapping(address => bool) in_game;
    

    constructor() payable{
        owner = payable(msg.sender);
    }
    modifier onlyOwner {
	    require(msg.sender == owner ,"caller is not owner");
	    _; //given function runs here
	}
    modifier primed {
	    require(is_primed[msg.sender],"caller has not primed their next move");
	    _; //given function runs here
	}
    modifier hprimed {
	    require(hit_primed[msg.sender],"caller has not primed their next move");
	    _; //given function runs here
	}
    modifier sprimed {
	    require(stand_primed[msg.sender],"caller has not primed their next move");
	    _; //given function runs here
	}
    modifier new_game {
        require(!in_game[msg.sender],"caller has not finished their game");
        _; //given function runs here
    }
    modifier game_in {
        require(in_game[msg.sender],"caller is not in a game");
        _; //given function runs here
    }
    function depo() internal {
        require(balances[msg.sender] + msg.value >= balances[msg.sender]);
        require(address(this).balance >= ((msg.value+balances[msg.sender]) * 3),"contract cant afford to pay you");
            balances[msg.sender] += msg.value;
    }
    function prime_move() internal {
        require(userblock[msg.sender] < 1,"move is already primed");
        userblock[msg.sender] = block.number + 1;
        is_primed[msg.sender] = true;
    }
    function un_prime() internal {
        is_primed[msg.sender] = false;
        hit_primed[msg.sender] = false;
        stand_primed[msg.sender] = false;
        userblock[msg.sender] = 0;   
    }
    function buy_in() external payable new_game {
        prime_move();
        depo();
    }
    function deal() external primed new_game returns(uint256,uint256,uint,uint256){
        in_game[msg.sender] = true;
        games[msg.sender]++;
        all_game_counter++;
        user_hand_value[msg.sender] = 0;
        user_aces[msg.sender] = 0;
        dealer_hand_value[msg.sender] = 0;
        dealer_aces[msg.sender] = 0;
        uint256 card1 = uget_card();
        FACTOR += userblock[msg.sender];  
        uint256 card2 = uget_card();
        FACTOR += userblock[msg.sender];  
        uint256 card3 = dget_card();
        FACTOR += userblock[msg.sender];         
        un_prime();
        if(user_hand_value[msg.sender] == 21){
            dget_card();
            last_outcome[msg.sender] = _result_check();
            in_game[msg.sender] = false;
            payout();
        }
        return(card1,card2,0,card3);
    }
    function prime_hit() external game_in {
        require(user_hand_value[msg.sender] < 21,"user's hand is too big and can no longer hit");
        hit_primed[msg.sender]=true;
        prime_move();
    }
    function hit() external primed hprimed game_in returns(uint256,uint256){
        require(user_hand_value[msg.sender] < 21,"user's hand is too big and can no longer hit");
        uint256 ncard = uget_card();        
        un_prime();
        //    prime_move();
        return (ncard,user_hand_value[msg.sender]);
    }
    function prime_stand() external game_in {
        stand_primed[msg.sender]=true;
        prime_move();
    }
    function stand() external primed sprimed game_in returns(uint256,uint256,uint) {
        if(user_hand_value[msg.sender] < 22){
            while(dealer_hand_value[msg.sender] < 17){
            dget_card();
            }
        }
        un_prime();
        last_outcome[msg.sender] = _result_check();
        in_game[msg.sender] = false;
        payout();
        return (user_hand_value[msg.sender],dealer_hand_value[msg.sender],last_outcome[msg.sender]);
    }
    function check_cards() external view returns(uint256 your_aces,uint256 your_hand,uint256 dealers_aces,uint256 dealers_hand){
        return (user_aces[msg.sender],user_hand_value[msg.sender],dealer_aces[msg.sender],dealer_hand_value[msg.sender]);
    }
    // function game_status() external view returns(bool In_Game,uint256 Bet,bool Hit_Primed,bool Stand_Primed){
    //     return (in_game[msg.sender],balance_of_me(),hit_primed[msg.sender],stand_primed[msg.sender]);
    // }
    function new_card() internal view returns(uint256) {
        return 1+(uint256(keccak256(abi.encodePacked(blockhash(userblock[msg.sender]),FACTOR)))%13);
    }
    function card_logic_user(uint256 card_num) internal returns(uint256) {
        uint256 card_value;
        //if card face = 10
        if(card_num > 9) {
            card_value = 10;
        }
        //if card is ace
        else if (card_num == 1){
            card_value = 11;
            user_aces[msg.sender]++;
        }
        //normal card
        else{
            card_value = card_num;
        }
        //if they're gonna bust
        if (user_hand_value[msg.sender]+card_value>21){
            if (user_aces[msg.sender] > 0){
                user_hand_value[msg.sender] -= 10;
                user_aces[msg.sender]--;
            }
        }
        user_cards[msg.sender]++;
        user_hand_value[msg.sender] += card_value;
        return card_num;
    }
    function uget_card() internal returns(uint256){
        return card_logic_user(new_card());
    }
    function dget_card() internal returns(uint256){
        return card_logic_dealer(new_card());
    }

    function card_logic_dealer(uint256 card_num) internal returns(uint256) {
        uint256 card_value;
        //if card face = 10
        if(card_num > 9) {
            card_value = 10;
        }
        //if card is ace
        else if (card_num == 1){
            card_value = 11;
            dealer_aces[msg.sender]++;
        }
        //normal card
        else{
            card_value = card_num;
        }

        //if they're gonna bust
        if (dealer_hand_value[msg.sender]+card_value>21){
            if (dealer_aces[msg.sender] > 0){
                dealer_hand_value[msg.sender] -= 10;
                dealer_aces[msg.sender]--;
            }
        }
        dealer_cards[msg.sender]++;
        dealer_hand_value[msg.sender] += card_value;
        return card_num;
    }
    function outcome() external view returns(uint){
        return last_outcome[msg.sender];
    }
   
     function payout() internal new_game {
        address payable _receiver = payable(msg.sender);
        if (last_outcome[msg.sender] == 3){
            balances[msg.sender] = (balances[msg.sender]/2);
        }
        earnings[msg.sender] += (balances[msg.sender] * last_outcome[msg.sender]);
        _receiver.transfer(balances[msg.sender] * last_outcome[msg.sender]);
        balances[msg.sender] = 0;
    }

    function _result_check() internal returns(uint){
        uint won;
        if(dealer_hand_value[msg.sender] == 21 && dealer_cards[msg.sender] == 2){
            if(user_hand_value[msg.sender] == 21 && user_cards[msg.sender] == 2){
                ties[msg.sender]++;
                won =1;
            }
            else{
                won = 0;
            }
        }
        else if(user_hand_value[msg.sender] == 21 && user_cards[msg.sender] == 2){
            wins[msg.sender]++;
            won = 3;
        }
        else if(user_hand_value[msg.sender] > 21){
            won = 0;  
        }
        else if(dealer_hand_value[msg.sender] > 21){
            wins[msg.sender]++;
            won = 2;
        }
        else if(user_hand_value[msg.sender] > dealer_hand_value[msg.sender]){
            wins[msg.sender]++;
            won=2;
        }
        else if(user_hand_value[msg.sender] == dealer_hand_value[msg.sender]){
            ties[msg.sender]++;
            won =1;
        }
        else {
            won=0;
        }
        return won;
    }
//   function balance_of_me() public view returns (uint balance) {
//     return balances[msg.sender];
//   }
  
  function win_ratio() external view returns (uint256 Wins,uint256 Ties,uint256 Games) {
    return (wins[msg.sender],ties[msg.sender],games[msg.sender]);
  }
  
  function return_balance (address payable adr) external onlyOwner {
    adr.transfer(address(this).balance);
  } 
  receive () external payable {}
}