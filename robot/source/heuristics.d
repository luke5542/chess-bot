import std.math;
import std.algorithm;

import montecarlo;
import gamestate;

real calculateUtility(GameState state, Side mySide)
{
    real result = 0;

    real mySideSeeds = reduce!((a,b) => a + b)(0, state.board[mySide]);
    real oppSeeds = reduce!((a,b) => a + b)(0, state.board[mySide.opposite]);
    real seedDiff = mySideSeeds - oppSeeds;

    real myPot = mySide == Side.NORTH ? state.northPit : state.southPit;
    real oppPot = mySide == Side.SOUTH ? state.northPit : state.southPit;

    if(myPot != oppPot && (myPot != 0 || oppPot != 0))
    {
        if(myPot > oppPot)
        {
            result = ((1.0 / myPot * (myPot - oppPot) + 1) * myPot) * 13;
        }
        else
        {
            result = ((1.0 / oppPot * (oppPot - myPot) + 1) * oppPot) * -11;
        }
    }

    foreach(hole; Hole.ONE .. Hole.SEVEN) // Hole.ONE -> Hole.SEVEN
    {
        // Can I capture something?
        if(state.getSeedsInHole(mySide, hole) == 0 && doesAMoveLandHere(state, mySide, hole))
        {
            result += state.getSeedsInHole(mySide.opposite, Hole.SEVEN - hole) * 11;
        }

        //Can I go again?
        if(8 - hole == state.getSeedsInHole(mySide, hole))
        {
            result += 100;
        }

        // Can they capture something?
        if(state.getSeedsInHole(mySide.opposite, hole) == 0 && doesAMoveLandHere(state, mySide.opposite, hole))
        {
            result -= state.getSeedsInHole(mySide, Hole.SEVEN - hole) * 13;
        }
    }
            
    // Can they go again?    
    //result = leadsToAdditionalMove(state, mySide) ? result / 3 : result * 3;

    //result += seedDiff;

    if(myPot > MAX_SEEDS / 2)
    {
        result += 10000;
    }
    else if(oppPot > MAX_SEEDS / 2)
    {
        result -= 10000;
    }
    
    result += (43 * (myPot - oppPot)) - 33*myPot + 16.5*oppPot;

    return isNaN(result) ? 0 : result;
}

// Does there exist a move behind this hole that will lead to a capture scenario if this hole is empty?
bool doesAMoveLandHere(GameState board, Side mySide, int endHole)
{
    for(int i = 0; i < endHole - 1; i++)
    {
        if(endHole == board.getSeedsInHole(mySide, cast(Hole) i))
        {
            // There does exist a move behind us that finally lands here!
            return true;
        }
    }

    return false;
}

// From the current state is the opponent able to get another turn?
bool leadsToAdditionalMove(GameState board, Side mySide)//, Move move)
{
    //GameState newBoard = board.performMove(move);
    foreach(hole; Hole.ONE .. Hole.SEVEN)
    {
        if(8 - hole == board.getSeedsInHole(mySide.opposite, hole))
        {
            //The opponent is able to end their turn in their pit
            return true;
        }
    }

    return false;
}

double calculateOldUtility(GameState state, Side mySide)
{
    int seedsInMyPit;
    int seedsInOpPit;

    if (state.side == mySide && state.side == Side.NORTH 
        || state.side != mySide && state.side == Side.SOUTH)
    {
        seedsInMyPit = state.northPit;
        seedsInOpPit = state.southPit;
    }
    else
    {
        seedsInMyPit = state.southPit;
        seedsInOpPit = state.northPit;
    }

    double distanceToOpponent = seedsInMyPit - seedsInOpPit;
    double meToWin = (MAX_SEEDS / 2 + 1) - seedsInMyPit;
    double opponentToWin = (MAX_SEEDS / 2 + 1) - seedsInOpPit;
    double seedsNearby = reduce!((a,b) => a + b)(0, state.board[mySide][Hole.FIVE..$]);
    double seedsFar = reduce!((a,b) => a + b)(0, state.board[mySide][Hole.THREE..Hole.SIX]);
    double seedsMiddle = reduce!((a,b) => a + b)(0, state.board[mySide][Hole.ONE..Hole.THREE]);

    if(seedsInMyPit > MAX_SEEDS / 2)
    {
        return 100000;
    }
    else if(seedsInOpPit > MAX_SEEDS / 2)
    {
        return -100000;
    }

    if(mySide == Side.SOUTH)
    {
        return (w1S * distanceToOpponent + w2S * meToWin + w3S * opponentToWin + w4S * seedsNearby + w5S * seedsFar + w6S * seedsMiddle);
    }
    else
    {
        return (w1N * distanceToOpponent + w2N * meToWin + w3N * opponentToWin + w4N * seedsNearby + w5N * seedsFar + w6N * seedsMiddle);
    }
    
}

double w1N = 86;
double w2N = -132;
double w3N = 66;
double w4N = 0.5;
double w5N = 0;
double w6N = -1;


double w1S = 100.1;
double w2S = -132.1;
double w3S = 66.1;
double w4S = 3.3;
double w5S = 0;
double w6S = -3.3;