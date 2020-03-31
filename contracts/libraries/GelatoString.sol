pragma solidity ^0.6.4;

library GelatoString {
    function startsWithOk(string memory _str) internal pure returns(bool) {
        if (bytes(_str).length >= 2 && bytes(_str)[0] == "O" && bytes(_str)[1] == "k")
            return true;
        return false;
    }
}