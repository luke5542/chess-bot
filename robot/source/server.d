import std.stdio;
import std.array;
import std.conv;
import std.process;
import std.string;
import std.encoding;
import std.stdio;
import std.exception;

import message;
import gamestate;

Side playerSide;

//Output message to server
void send(OutMessage outMsg)
{
    if(cast(SwapMessage) outMsg)
    {
        playerSide = playerSide == Side.SOUTH ? Side.NORTH : Side.SOUTH;
    }
    debug stderr.writeln("Output: ", outMsg);
    stdout.write(outMsg.toString());
    stdout.flush();

}

//Receive message from server, returns null if no message available
InMessage receive() {
    string input = stdin.readln();
    if(input is null)
    {
        return null;
    }
    else
    {
        return parseMessage(input);
    }
}

//For manually testing of server parsing code
InMessage receive(string input)
{   
    return parseMessage(input);
}

InMessage parseMessage(string input)
{
    debug stderr.writeln("Received: ", input);
    //Split input on protocol delimiter
    string[] tokens = split(toUpper(strip(input)), ";");

    //Check that there is more than one token
    if(tokens.length > 0)
    {
        //Inital branch based on first token
        switch(tokens[0])
        {
            //Create start message and set player side
            case "START":
                auto inMsg = new StartMessage(tokens[1]);
                playerSide = inMsg.initialSide();
                return inMsg;
            //End of game message
            case "END":
                auto inMsg = new EndMessage();
                return inMsg;
            //Handles the two change messages
            case "CHANGE":
                //Swap player sides message
                if(tokens[1] == "SWAP")
                {
                    enforce(tokens.length == 4, "Malformed server output exception - Incorrect swap message length");
                    auto inMsg = new SwapChangeMessage(playerSide, tokens[2], tokens[3]);
                    playerSide = (playerSide == Side.NORTH ? Side.SOUTH : Side.NORTH);
                    return inMsg;
                }
                //Move made message
                else
                {
                    enforce(tokens.length == 4, "Malformed server output exception - Incorrect swap message length");
                    auto inMsg = new MoveChangeMessage(playerSide, to!int(tokens[1]), tokens[2], tokens[3]);
                    return inMsg;
                }
            //Handle any other dodgy inputs
            default:
                throw new Exception("Malformed server output exception - No valid command");
        }
    }
    else
    {
        return null;
    }   
}

unittest
{
    writeln("Testing server and message code.");

    MoveMessage mMessage = new MoveMessage(Hole.ONE);
    assert(mMessage.toString() == "MOVE;1\n");
    mMessage = new MoveMessage(Hole.SEVEN);
    assert(mMessage.toString() == "MOVE;7\n");

    SwapMessage sMessage = new SwapMessage();
    assert(sMessage.toString() == "SWAP\n");

    InMessage inMsg = receive("START;North\n");
    assert(playerSide == Side.NORTH);

    inMsg = receive("START;South\n");
    assert(playerSide == Side.SOUTH);

    assert(GameState(Side.SOUTH) == inMsg.getNextState());

    inMsg = receive("CHANGE;SWAP;0,8,8,8,8,8,8,1,7,7,7,7,7,7,7,0;YOU\n");
    GameState newState = inMsg.getNextState();
    assert(playerSide == newState.side);
    writeln("Recieved game state: ");
    writeln(newState.toString());
    writeln("From input: CHANGE;SWAP;0,8,8,8,8,8,8,1,7,7,7,7,7,7,7,0;YOU\n");

    inMsg = receive("END\n");
    assert(inMsg.getPhase() == Phase.END);

    writeln("Server test complete.");
}