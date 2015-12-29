import std.stdio;
import std.array;
import std.conv;
import std.string;
import std.exception;

import gamestate;
import server;

enum Phase {START, ONGOING, END}

interface InMessage
{
    GameState getNextState();
    Phase getPhase();
}

GameState parseState(Side nextTurn, string states)
{
    //Split the state segment of message
    int[] allStates = to!(int[])(split(states, ","));
    enforce(allStates.length == 16, "Incorrect no. of states received");
    //Assign north side of board values
    int[7] northBoard = allStates[0..7];
    int[2] pits;
    //Assign north pit
    pits[Side.NORTH] = allStates[7];
    int[7] southBoard = allStates[8..15];
    //Assign south pit
    pits[Side.SOUTH] = allStates[15];

    //Return next state value
    return GameState(nextTurn, southBoard, northBoard, pits);
}

class StartMessage : InMessage
{
    immutable Side side;
    private GameState nextState;

    //Constructs from the <SIDE> of split message <MSG>;<SIDE>
    this(string message)
    {
        this.side = to!Side(toUpper(message));
        nextState = GameState(Side.SOUTH);
    }

    //Returns the initial side the player starts on
    Side initialSide()
    {
        return side;
    }

    //Get the next state (initial state)
    override GameState getNextState()
    {
        return nextState;
    }

    override Phase getPhase()
    {
        return Phase.START;
    }
}

class MoveChangeMessage : InMessage
{
    private GameState nextState;
    bool endMsg = false;

    this(Side yourSide, int move, string states, string turn)
    {
        int[7] northBoard;
        int[7] southBoard;
        int[2] pits;

        //Translation of input turn message to Side enum
        Side nextTurn;
        switch(toUpper(turn))
        {
            case "YOU":
                nextTurn = yourSide;
                break;
            case "OPP":
                nextTurn = (yourSide == Side.NORTH ? Side.SOUTH : Side.NORTH);
                break;
            case "END":
                endMsg = true;
                break;
            default:
                //If the input isn't any of the above...
                throw new Exception("Malformed input exception");
        }

        //Set next state value
        nextState = parseState(nextTurn, states);
    }

    override GameState getNextState()
    {   
        return nextState;
    }

    override Phase getPhase()
    {
        return endMsg ? Phase.END : Phase.ONGOING;
    }
}

class SwapChangeMessage : InMessage
{
    private GameState nextState;
    bool endMsg = false;

    this(Side yourSide, string states, string turn)
    {
        int[7] northBoard;
        int[7] southBoard;
        int[2] pits;

        //Translation of input turn message to Side enum
        Side nextTurn;
        switch(toUpper(turn))
        {
            case "YOU":
                nextTurn = (yourSide == Side.NORTH ? Side.SOUTH : Side.NORTH);
                break;
            case "OPP":
                nextTurn = yourSide;
                break;
            case "END":
                endMsg = true;
                break;
            default:
                //If the input isn't any of the above...
                throw new Exception("Malformed input exception");
        }

        //Set next state value
        nextState = parseState(nextTurn, states);
    }

    override GameState getNextState()
    {
        return nextState;
    }

    override Phase getPhase()
    {
        return endMsg ? Phase.END : Phase.ONGOING;
    }
}

class EndMessage : InMessage
{
    private GameState nextState;

    this() {}

    //Well, if this class instance exists then it has ended ^_^
    override Phase getPhase()
    {
        return Phase.END;
    }

    override GameState getNextState()
    {
        return GameState();
    }
}

interface OutMessage
{
    //For output to server...
    string toString();
}

class MoveMessage : OutMessage
{
    Hole hole;

    this(Hole hole)
    {
        this.hole = hole;
    }

    //Output message MOVE;<NAT>\n
    override string toString()
    {
        return "MOVE;" ~ to!string(to!int(hole) + 1) ~ '\n';
    }
}

class SwapMessage : OutMessage
{
    this() {}

    //Output message SWAP\n
    override string toString()
    {
        return "SWAP" ~ '\n';
    }
}

unittest 
{
    writeln("Testing side message assignment.");

    StartMessage sSMessage = new StartMessage("south");
    assert(sSMessage.initialSide() == Side.SOUTH);

    StartMessage sNMessage = new StartMessage("north");
    assert(sNMessage.initialSide() == Side.NORTH);

    writeln("Passed side message assignment test.");
}