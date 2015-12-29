import std.stdio;
import std.concurrency;
import std.random;
import std.math;
import std.conv;

import core.time;

import gamestate;
import idlethread;
import server;
import heuristics;
import montecarlo;

class MTDfTreeNode
{
  //The children moves from this node
  MTDfTreeNode[7] m_children;
  MTDfTreeNode m_parent;

  //The current state of the game at this point
  GameState m_currentState;

  //The move that gets you to this node.
  Move m_moveToHere;

  bool m_isLeaf = true;
}

struct StateDetails
{
    real upperBound;
    real lowerBound;
}

__gshared real[GameState] transpositionTableUpper;
__gshared real[GameState] transpositionTableLower;

real alphaBetaWithMemory(GameState state, real alpha, real beta, int depth)
{
    real g=0, a=0, b=0;
    int i;
    Move[] moves;
    real oldUpperBound = real.max;
    real oldLowerBound = -real.max;

    //synchronized
    //{
        real* foundValUpper = (state in transpositionTableUpper);
        real* foundValLower = (state in transpositionTableLower);
        //StateDetails* foundValue = (state in transpositionTable);

        //Do the aspects relating to the transposition table lookup...
        if(foundValUpper !is null)
        {
            if(*foundValUpper <= alpha)
                return *foundValUpper;

            beta = fmin(beta, *foundValUpper);
            oldUpperBound = *foundValUpper;
        }
        if(foundValLower)
        {
            if(*foundValLower >= beta)
                return *foundValLower;

            alpha = fmax(alpha, *foundValLower);
            oldLowerBound = *foundValLower;
        }

    if(depth == 0 || state.getMyValidMoves().length == 0)
    {
        //Calculate utility?
        g = calculateOldUtility(state, server.playerSide);
        //g = calculateOldUtility(state, server.playerSide);
        //stderr.writeln("reached end of depth..");
    }
    else if(state.side != server.playerSide) // n is a max node...
    {
        g = -real.max;
        a = alpha;

        moves = state.getMyValidMoves();
        i = 0;
        GameState nextState;
        while(g < beta && i < moves.length)
        {
            //writeln(i);
            nextState = state.performMove(moves[i]);
            g = fmax(g, alphaBetaWithMemory(nextState, a, beta, depth-1));
            a = fmax(a, g);

            i++;
        }
    }
    else // n is a min node...
    {
        g = real.max;
        b = beta;

        moves = state.getMyValidMoves();
        i = 0;
        GameState nextState;
        while(g > alpha && i < moves.length)
        {
            nextState = state.performMove(moves[i]);
            g = fmin(g, alphaBetaWithMemory(nextState, alpha, b, depth-1));
            b = fmin(b, g);
            
            i++;
        }
    }

    //bool store = false;


    /* Traditional transposition table storing of bounds */
    /* Fail low result implies an upper bound */
    if(g <= alpha)
    {
        transpositionTableUpper[state] = g;
        transpositionTableLower[state] = oldLowerBound;
    }
    /* Found an accurate minimax value – will not occur if called with zero window */
    else if(g > alpha && g < beta)
    {
        transpositionTableUpper[state] = g;
        transpositionTableLower[state] = g;
    }
    /* Fail high result implies a lower bound */
    else
    {
        transpositionTableUpper[state] = oldUpperBound;
        transpositionTableLower[state] = g;
    }

    return g;
}
