import std.math;
import std.exception;
import std.stdio;

import tree;
import gamestate;
import heuristics;
import server;

immutable MAX_SEARCH_DEPTH = 35;

Move getMTDfMove(GameState state)
{
    auto moves = state.getMyValidMoves();

    if(moves.length == 0)
    {
        return Move();
    }

    ulong bestMoveIndex = 0;
    real bestMoveValue = -real.max;
    real guess = iterativeDeepening(state);
    GameState nextState;

    foreach(index, move; moves)
    {
        nextState = state.performMove(move);
        iterativeDeepening(nextState);

        real* foundValUpper = (nextState in transpositionTableUpper);
        real* foundValLower = (nextState in transpositionTableLower);
        
        if(foundValUpper !is null && foundValLower !is null
            && ((*foundValLower - *foundValUpper) + *foundValLower) > bestMoveValue)
        {
            bestMoveValue = (*foundValLower - *foundValUpper) + *foundValLower;
            bestMoveIndex = index;
        }
    }

    return moves[bestMoveIndex];
}

//Iteratively deepen the tree starting from a root node
real iterativeDeepening(GameState rootState)
{
    real firstGuess = 0;
    //For each depth, down to the max depth, run the mtdf function
    foreach(depth; 1..MAX_SEARCH_DEPTH)
    {
        firstGuess = mtdf(rootState, firstGuess, depth);
        //Break here if out of time
        //writeln(firstGuess);
    }
    return firstGuess;
}

//Calculates a value guess from the tree down to a depth
real mtdf(GameState rootState, real f, int depth)
{
    real guess = f;
    real upperbound = real.max;
    real lowerbound = -real.max;
    while(lowerbound < upperbound) 
    {
        real beta = 0;
        if(guess == lowerbound)
        {
            beta = guess + 1;
        }
        else
        {
            beta = guess;
        }
        guess = alphaBetaWithMemory(rootState, beta-1, beta, depth);
        if(guess < beta)
        {
            upperbound = guess;
        }
        else
        {
            lowerbound = guess;
        }
    }
    return guess;
}