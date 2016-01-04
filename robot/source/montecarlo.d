import std.stdio;
import std.concurrency;
import std.random;
import std.math;
import std.conv;

import core.time;
import core.thread;

import gamestate;
import app;

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

class MCTreeNode
{
    //The children moves from this node
    MCTreeNode[] m_children;

    MCTreeNode parent;

    bool m_isLeafNode = true;

    //The current state of the game at this point
    GameState m_currentState;

    //The move that gets you to this node.
    Move m_moveToHere;

    // Keep if it is my turn or the opponents one.
    bool myTurn;

    real nodeValue = 0;

    // Variables from the selection formula.
    real w = 0; // Number of wins after this move.
    real n = 1; // Number of simulations after this move.
    real c = SQRT2; // Exploration parameter
    
    this(GameState state, Move move)
    {
        m_currentState = state;
        m_moveToHere = move;
    }

    real obtainUtility()
    {
        return w / n;
    }

    bool isLeafNode()
    {
        return m_isLeafNode;
    }

    real getSearchParameter(real parentN)
    {
        return (c * sqrt(log(parentN) / n));
    }

}


// Create a tree having the node with the current state as root.
MCTreeNode root = null;
bool canSearchTree = false;

// Run till interrupted.
void runBot()
{
    debug writeln("Running Monte Carlo Tree Search...");

    try
    {
        bool done = false;
        while(!done) {
            if(root !is null && canSearchTree)
                expandTree();
            else
                Thread.sleep(msecs(50));

            //Check for server messages...
            done = checkMessages();
        }

        debug writeln("MCT Thread is exiting.");
  
    }
    catch(Exception e)
    {
        writeln(e);
    }
} // execute

void expandTree()
{
    MCTreeNode newNode, currentNode;

    // Selection
    debug writeln("Selecting...");
    currentNode = root;

    while(!currentNode.isLeafNode())
    {

        newNode = null;
        
        // Look at all the children and get the most promising one.
        foreach(child; currentNode.m_children)
        {
            if (child !is null)
            {
                child.nodeValue = child.obtainUtility() + child.getSearchParameter(currentNode.n);
                
                if (newNode is null || (currentNode.myTurn && child.nodeValue > newNode.nodeValue)
                                || (!currentNode.myTurn && child.nodeValue < newNode.nodeValue))
                {
                    newNode = child;
                } // if this child looks more promising
            } // if child not null
        } // for each child

        currentNode = newNode;
    } // while

    debug writeln("Found leaf node... ", currentNode is null);

    // Expansion
    // Unless current node ends the game
    // Create all the children and choose the most promising one.
    Move[] moves = currentNode.m_currentState.getMyValidMoves();
    debug writeln("Num moves: ", moves.length);
    if(currentNode.m_currentState.currentState == PlayState.PLAYING && moves.length > 0)
    {
        debug writeln("Not end game");

        MCTreeNode mostPromising;
        //real promisingValue = 0;

        //Make sure currentNode is no longer a leaf.
        currentNode.m_isLeafNode = false;

        real prevUtility = currentNode.obtainUtility();
        foreach(index, move; moves)
        {
            MCTreeNode newChild = new MCTreeNode(currentNode.m_currentState.performMove(move), move);
            newChild.parent = currentNode;
            newChild.myTurn = (newChild.m_currentState.side == currentNode.m_currentState.side) 
                            ? currentNode.myTurn : !currentNode.myTurn;
            //newChild.c = newChild.myTurn ? MY_SEARCH_RATE : OPP_SEARCH_RATE;

            currentNode.m_children[index] = newChild;

            if(mostPromising is null || newChild.obtainUtility() >= mostPromising.obtainUtility())
            {
                mostPromising = newChild;
            }
        }

        currentNode = mostPromising;
    } // perform expansion

    debug writeln("Simulating...");
    bool wonSimulation;
    if(currentNode.myTurn)
    {
        wonSimulation = simulateGame(currentNode.m_currentState, currentNode.m_currentState.side);
    }
    else
    {
        wonSimulation = simulateGame(currentNode.m_currentState,
                                        currentNode.m_currentState.side.opposite);
    }

    debug writeln("Back propagating...");
    backpropagate(wonSimulation, currentNode.parent);
}

bool checkMessages()
{
    try
    {
        //debug writeln("Checking for messages...");
        receiveTimeout( 1.usecs,
                (string message) {
                    debug writeln("Exiting");
                    return true;
                },
                (GetBestMove message) {
                    debug writeln("Getting best move...");
                    //Send message to parent with the best move found so far
                    if(!root.myTurn)
                    {
                        debug writeln("It's not my turn, something went wrong ya doof...");
                    }
                    Move bestMove;
                    real bestVal = 0;
                    bool hasBestMove = false;
                    foreach(node; root.m_children)
                    {
                        if(node !is null && (!hasBestMove || node.obtainUtility() > bestVal))
                        {
                            bestMove = node.m_moveToHere;
                            bestVal = node.obtainUtility();
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
                    canSearchTree = false;
                },
                (Move moveMade) {
                    //update the tree with the new data
                    debug writeln("Pruning tree with move...");

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
                    canSearchTree = true;
                },
                (GameState newState, bool myTurn) {
                    root = new MCTreeNode(newState, Move());

                    // Set it up.
                    root.m_currentState = newState;
                    root.myTurn = myTurn;
                    canSearchTree = myTurn;
                },
                (PrintTreeStats message) {
                    //Print out various statistics about this tree.
                    //printTreeStats(root);
                });
    }
    catch(OwnerTerminated exc)
    {
        //Do same as the Exit message
        debug writeln("Exiting due to parental termination.");
        return true;
    }
    
    return false;
}

// Perform the simulation part of the Monte Carlo algortihm by executing
// random moves from the current game state.
bool simulateGame(GameState state, Color myColor)
{
    Move[] moves = state.getMyValidMoves();
    int randomIndex;

    while(state.currentState == PlayState.PLAYING)
    {
        randomIndex = to!int(uniform(0, moves.length));

        // Randomly perform one
        state = state.performMove(moves[randomIndex]);

        // Get the possible moves
        moves = state.getMyValidMoves();
    } // while there are still possible moves.

    // Check who has won.
    return state.isWinner(myColor);

} // simulateGame

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

/*void printTreeStats(MCTreeNode root)
{
  //TODO print out the various tree statistics...
  writeln("Root children: ");

  foreach(child; root.m_children)
  {
    if(child !is null)
      writeln("Node Value: ", child.nodeValue, ", Wins past this point: ", 
      								child.w, ", Simulations: ", child.n, ", Utility: ", child.obtainUtility(),
                      ", Average Utility below: ", child.childrenAverageUtility,
                      ", Total Utility below: ", child.childrenUtility,
                      ", Search Parameter: ", child.getSearchParameter(root.n));
  }

  int numNodes = getNumNodes(root);
  writeln("Number of Nodes: ", numNodes);
  //writeln("Seeds North: ", root.m_currentState.northPit, ", Seeds South: ", 
  									//root.m_currentState.southPit);
  writeln();
}//*/

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
/*void updateAveragedUtility(MCTreeNode node, real oldValue, real newValue)
{
	if(node !is null)
	{
        real prevUtility = node.childrenAverageUtility;
        
        node.childrenUtility -= oldValue;
        node.childrenUtility += newValue;
        node.childrenAverageUtility = node.childrenUtility / node.numberOfExpandedChildren;
        
        updateAveragedUtility(node.parent, prevUtility, node.childrenAverageUtility);
	}
}//*/
