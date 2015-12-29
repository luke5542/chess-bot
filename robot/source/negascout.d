import std.math;

import heuristics;
import gamestate;
import server;

immutable MAX_SEARCH_DEPTH = 50;

Move getNegaScoutMove(GameState state)
{
   auto moves = state.getMyValidMoves;

   if(moves.length == 0)
   {
      return Move();
   }

   GameState nextState;
   real nodeVal;
   bool nodeFound = false;
   real bestNodeVal;
   Move bestMove;

   foreach(index, move; moves)
   {
      nextState = state.performMove(move);
      nodeVal = negascout(nextState, real.max, -real.max, 0);

      if(!nodeFound || nodeVal > bestNodeVal)
      {
         bestMove = move;
         bestNodeVal = nodeVal;
      }
   }

   return bestMove;
}

real negascout(GameState state, real alpha, real beta, int depth)  
{
    real a = 0;
    real b = 0;
    real t = 0;

    auto moves = state.getMyValidMoves();
    if(moves.length == 0)
        return calculateOldUtility(state, server.playerSide);

    a = alpha;
    b = beta;
    foreach(index, move; moves) 
    {
        t = -negascout(state.performMove(moves[index]), -b, -a, depth+1);
        if ((t > a) && (t < beta) && (index > 1) && (depth < MAX_SEARCH_DEPTH-1))
            a = -negascout(state.performMove(moves[index]), -beta, -t, depth+1);

        a = fmax(a, t);

        if(a >= beta) 
            return a;

        b = a + 1;
    }
    return a;
}