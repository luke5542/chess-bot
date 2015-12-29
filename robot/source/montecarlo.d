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

immutable MY_SEARCH_RATE = 65;
immutable OPP_SEARCH_RATE = 80;

//This is a placeholder to be used in message passing
//to return to the best move found so far to the main thread.
struct GetBestMove {}

//The message sent when there are no moves.
struct NoMoves {}

//This is used for debug only, to tell the MCT to print
//available statistics on the tree itself.
struct PrintTreeStats {}

// Run the Monte Carlo program in order to play a mancala game.
// Number of seeds in the game
immutable MAX_SEEDS = 98;

class MCTreeNode
{
  //The children moves from this node
  MCTreeNode[7] m_children;
  
  MCTreeNode parent;

  bool m_isLeafNode = true;

  //The current state of the game at this point
  GameState m_currentState;

  //The move that gets you to this node.
  Move m_moveToHere;

  //To say whether or not the move to get here is a valid move or not.
  bool m_isValid;
  
  // Keep if it is my turn or the opponents one.
  bool myTurn;
  
  // The three heuristics.
  int distanceToOpponent;
  int meToWin;
  int opponentToWin;
  
  // NEW heuristics
  real childrenAverageUtility = 0;
  real childrenUtility = 0;
  int numberOfExpandedChildren = 0;

  real newUtilityValue = 0;

  real nodeValue = 0;
  
  // Variables from the selection formula.
  int w = 0; // Number of wins after this move.
  int n = 1; // Number of simulations after this move.
  real c = SQRT2; // Exploration parameter  
  
  real obtainUtility()
  {
    return newUtilityValue;//(distanceToOpponent - meToWin + opponentToWin);
  } // obtainUtility
  
  bool isLeafNode()
  {
    return m_isLeafNode;
  }
  
  real obtainWinningScore()
  {
    real score = /*sqrt(cast(real) (this.obtainUtility()^^2 + */this.childrenAverageUtility;//^^2;));
    return score;//obtainUtility() < 0 ? -score : score;
  }

  real getSearchParameter(real parentN)
  {
    return (c * sqrt(log(parentN) / n));
  }

} // MCTreeNode

// Run till interrupted.
void execute(GameState state)
{
  debug stderr.writeln("Running Monte Carlo Tree Search...");

  try
  {
    bool done = false;

    // Create a tree having the node with the current state as root.
    MCTreeNode root = new MCTreeNode();
    
    // Set it up.
    root.m_currentState = state;
    root.myTurn = true;

    // Update the heuristics
    //updateHeuristics(root);
    root.newUtilityValue = calculateUtility(state, state.side);
    
    MCTreeNode currentNode;

    do {       
      MCTreeNode newNode;
      
      // Selection
      debug stderr.writeln("Selecting...");
      currentNode = root;
      
      while(!currentNode.isLeafNode())
      {
        
        newNode = null;
        
        // Look at all the children and get the most promising one.
        foreach(child; currentNode.m_children)
        { 
          if (child !is null)
          {
            //child.nodeValue = child.w / child.n + child.c * sqrt(log(currentNode.n) / child.n);
            child.nodeValue = child.obtainUtility() + child.getSearchParameter(currentNode.n);
            //stderr.writeln("Node Val: ", child.nodeValue, ", Average Utility: ", child.childrenAverageUtility);
            
            if (newNode is null || (currentNode.myTurn && child.nodeValue > newNode.nodeValue)
                                || (!currentNode.myTurn && child.nodeValue < newNode.nodeValue))
            {
              newNode = child;
            } // if this child looks more promising          
          } // if child not null
        } // for each child
        
        currentNode = newNode;
        //stderr.writeln("Found new Node. isLeaf: ", currentNode.isLeafNode());
      } // while
        
      debug stderr.writeln("Found leaf node...");

      // Expansion
      // Unless current node ends the game
      // Create all the children and choose the most promising one.
      Move[] moves = currentNode.m_currentState.getMyValidMoves();
      if(!isEndGame(currentNode.m_currentState) && moves.length > 0)
      {
        debug stderr.writeln("Not end game");
        
        MCTreeNode mostPromising;
        //real promisingValue = 0;

        //Make sure currentNode is no longer a leaf.
        currentNode.m_isLeafNode = false;
        
        real prevUtility = currentNode.childrenUtility;
        foreach(index, move; moves)
        {
          MCTreeNode newChild = new MCTreeNode();
          newChild.m_currentState = currentNode.m_currentState.performMove(move);
          newChild.m_moveToHere = move;
          newChild.parent = currentNode;
          newChild.myTurn = (newChild.m_currentState.side == currentNode.m_currentState.side) 
                            ? currentNode.myTurn : !currentNode.myTurn;
          newChild.c = newChild.myTurn ? MY_SEARCH_RATE : OPP_SEARCH_RATE;
          
          //updateHeuristics(newChild);
          newChild.newUtilityValue = calculateUtility(newChild.m_currentState, server.playerSide);
          //stderr.writeln("Child New Utility: ", newChild.newUtilityValue);

          currentNode.m_children[index] = newChild;

          if (mostPromising is null || newChild.obtainUtility() >= mostPromising.obtainUtility())
          {
            mostPromising = newChild;
            //promisingValue = newChild.obtainUtility();
          }
          
          // Update NEW heuristics
          currentNode.numberOfExpandedChildren++;
          //Negatively weight bad children...
          currentNode.childrenUtility += newChild.obtainUtility();//newChild.myTurn ? newChild.obtainUtility() : -newChild.obtainUtility();        
        } // for each child
      
        if(currentNode.numberOfExpandedChildren == 0)
        {
          currentNode.childrenAverageUtility = 0;
        }
        else
        {
          currentNode.childrenAverageUtility = currentNode.childrenUtility 
                                             / currentNode.numberOfExpandedChildren;
        }
      
	      // Update for all the nodes above this one.
	      updateAveragedUtility(currentNode.parent, prevUtility,
	      											currentNode.childrenAverageUtility);  

        currentNode = mostPromising;    
      } // perform expansion

      // Simulation and Backpropagation
      currentNode.n += 1;

      debug stderr.writeln("Simulating...");
      bool wonSimulation;
      if(currentNode.myTurn)
      {
        wonSimulation = simulateGame(currentNode.m_currentState, currentNode.m_currentState.side);
      }
      else
      {
        if(currentNode.m_currentState.side == Side.NORTH)
        {
          wonSimulation = simulateGame(currentNode.m_currentState, Side.SOUTH);
        }
        else
        {
          wonSimulation = simulateGame(currentNode.m_currentState, Side.NORTH);
        }
      }

      debug stderr.writeln("Back propagating...");
      if(wonSimulation)
      {
          currentNode.w +=1;
          backpropagate(true, currentNode.parent);
      }
      else
          backpropagate(false, currentNode.parent);
      
      // Update tree

      //Check for server messages...
      try
      {
        debug stderr.writeln("Checking for messages...");
        receiveTimeout( 1.usecs,
                        (Exit message) {
                          debug stderr.writeln("Exiting");
                          done = true;
                        },
                        (GetBestMove message) {
                          debug stderr.writeln("Getting best move...");
                          //Send message to parent with the best move found so far
                          if(!root.myTurn)
                          {
                            debug stderr.writeln("It's not my turn, something went wrong ya doof...");
                          }
                          Move bestMove;
                          real bestVal = 0;
                          bool hasBestMove = false;
                          foreach(node; root.m_children)
                          {
                            if(node !is null && (!hasBestMove || node.obtainWinningScore() > bestVal))
                            {
                              bestMove = node.m_moveToHere;
                              bestVal = node.obtainWinningScore();
                              hasBestMove = true;
                            }
                          }
                          if(hasBestMove)
                          {
                            ownerTid.send(bestMove);
                          }
                          else
                          {
                            ownerTid.send(NoMoves());
                          }
                        },
                        (Move moveMade) {
                          //update the tree with the new data
                          debug stderr.writeln("Pruning tree with move...");

                          //Find node with given move...
                          foreach(node; root.m_children)
                          {
                            if(node !is null && node.m_moveToHere == moveMade)
                            {
                              root = node;
                              root.parent = null;
                              break;
                            }
                          }
                        },
                        (GameState newState) {
                          //update the tree with the new data
                          debug stderr.writeln("Pruning tree with GameState...");

                          bool nodeFound = false;
                          //Find node with given move...
                          foreach(node; root.m_children)
                          {
                            if(node !is null && node.m_currentState == newState)
                            {
                              root = node;
                              root.parent = null;
                              nodeFound = true;
                              break;
                            }
                          }

                          if(!nodeFound)
                          {
                            root = new MCTreeNode();
    
                            // Set it up.
                            root.m_currentState = newState;
                            root.myTurn = newState.side == server.playerSide;
                            //updateHeuristics(root);
                            root.newUtilityValue = calculateUtility(newState, server.playerSide);
                          }
                        },
                        (PrintTreeStats message) {
                          //Print out various statistics about this tree.
                          printTreeStats(root);
                        });
      }
      catch(OwnerTerminated exc)
      {
        //Do same as the Exit message
        debug stderr.writeln("Exiting due to parental termination.");
        done = true;
      }


      debug stderr.writeln("Time to loop...", '\n');
    } while(!done);

    debug stderr.writeln("MCT Thread is ending from lack of work.");
  
  }
  catch(Exception e)
  {
    stderr.writeln(e);
  }

} // execute

// Perform the simulation part of the Monte Carlo algortihm by executing
// random moves from the current game state.
bool simulateGame(GameState state, Side mySide)
{
  Move[] moves = state.getMyValidMoves();
  int randomIndex;
  
  while(state.northPit <= MAX_SEEDS/2 && state.southPit <= MAX_SEEDS/2 && moves.length > 0)
  {
    randomIndex = to!int(uniform(0, moves.length));
  
    // Randomly perform one
    state = state.performMove(moves[randomIndex]);
    
    // Get the possible moves
    moves = state.getMyValidMoves();
  } // while there are still possible moves.
  
  // Check who has won.
  if ((mySide == Side.NORTH && state.northPit > state.southPit)
      || (mySide == Side.SOUTH && state.southPit > state.northPit))
      return true;
  else
      return false; // We have lost :(    
      
  
} // simulateGame

void updateHeuristics(MCTreeNode node)
{
  int seedsInMyPit;
  int seedsInOpPit;
  
  if (node.myTurn && node.m_currentState.side == Side.NORTH 
      || !node.myTurn && node.m_currentState.side == Side.SOUTH)
  {
    seedsInMyPit = node.m_currentState.northPit;
    seedsInOpPit = node.m_currentState.southPit;
  }
  else
  {
    seedsInMyPit = node.m_currentState.southPit;
    seedsInOpPit = node.m_currentState.northPit;
  }
  
  node.distanceToOpponent = seedsInMyPit - seedsInOpPit;
  node.meToWin = (MAX_SEEDS / 2 + 1) - seedsInMyPit;
  node.opponentToWin = (MAX_SEEDS / 2 + 1) - seedsInOpPit;
} // updateHeuristics

void backpropagate(bool weWon, MCTreeNode currentNode)
{
  // While we havent arrived to the root.
  if (currentNode !is null)
  {
    if(weWon)
      currentNode.w +=1;
      
    currentNode.n += 1;
    
    backpropagate(weWon, currentNode.parent);  
    
  }
}

bool isEndGame(GameState state)
{
   return state.getMyValidMoves().length == 0; //(state.northPit >= (MAX_SEEDS / 2 + 1) || state.southPit >= (MAX_SEEDS / 2 + 1));
}

void printTreeStats(MCTreeNode root)
{
  //TODO print out the various tree statistics...
  stderr.writeln("Root children: ");

  foreach(child; root.m_children)
  {
    if(child !is null)
      stderr.writeln("Node Value: ", child.nodeValue, ", Wins past this point: ", 
      								child.w, ", Simulations: ", child.n, ", Utility: ", child.obtainUtility(),
                      ", Average Utility below: ", child.childrenAverageUtility,
                      ", Total Utility below: ", child.childrenUtility,
                      ", Search Parameter: ", child.getSearchParameter(root.n));
  }

  int numNodes = getNumNodes(root);
  stderr.writeln("Number of Nodes: ", numNodes);
  //stderr.writeln("Seeds North: ", root.m_currentState.northPit, ", Seeds South: ", 
  									//root.m_currentState.southPit);
  stderr.writeln();
}

int getNumNodes(MCTreeNode root)
{
  int total = 1;

  foreach(child; root.m_children)
  {
    if(child !is null)
    {
      if(child.m_isLeafNode)
      {
        total += 1;
      }
      else
      {
        total += getNumNodes(child);
      }
    }
  }

  return total;
}

// NEW method
void updateAveragedUtility(MCTreeNode node, real oldValue, real newValue)//, int numChildren, int oldChildren)
{
		if(node !is null)
		{
        real prevUtility = node.childrenAverageUtility;
        
        node.childrenUtility -= oldValue;
        node.childrenUtility += newValue;
        node.childrenAverageUtility = node.childrenUtility / node.numberOfExpandedChildren;
        
        updateAveragedUtility(node.parent, prevUtility, node.childrenAverageUtility);
		}
}
