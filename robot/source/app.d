import std.concurrency;
import std.stdio;
import std.conv;
import std.random;
import std.getopt;
import std.parallelism;
import core.stdc.stdlib;
import core.time;
import core.thread;

import montecarlo;
import gamestate;
import gui;

void main(string[] args)
{
    version(unittest)
    {
        writeln("Done running Unit Tests.");
    }
    else
    {
        runGui();
    }
}

GameState mainState;
Color guiSide;
Tid botThread;
bool botRunning = false;
bool isFirstMove = true;
void setupBotAndBeginGame(GameGUI gui)
{
    mainState.init();
    botThread = spawnLinked(&runBot);
    botThread.send(mainState, false);
    botRunning = true;
    
    gui.initializeGameBoard(mainState, true);
    guiSide = mainState.side;
    gui.playGame();
}

Move[] getMovesForLoc(int x, int y)
{
    return mainState.checkIfIsInCheck(guiSide, mainState.getMoves(cast(byte) x, cast(byte) y));
}

bool isMyPiece(int x, int y)
{
    return mainState.board[x][y].piece.color == guiSide;
}

void playMove(Move m)
{
    mainState = mainState.performMove(m);
    botThread.send(m);
}

void requestBotMove()
{
    botThread.send(GetBestMove());
}

//This will check if any messages have been passed to this thread,
//and update accordingly
void checkMessages(GameGUI gui)
{
    if(botRunning)
    {
        try
        {
            receiveTimeout( 1.usecs,
                    (string message) {
                        stderr.writeln("Exiting");
                        gui.gameOver = true;
                    },
                    (Move move) {
                        mainState = mainState.performMove(move);
                        gui.updateGuiForMove(move);
                    });
        }
        catch(LinkTerminated ltEx)
        {
            writeln(ltEx);
            gui.gameOver = true;
        }
    }
}

/*void playGameWithServer()
{
    bool awaitMessage = false;
    //Get the first message
    InMessage message = server.receive();
    while(!(cast(StartMessage) message))
    {
        message = server.receive();
    }

    StartMessage startMessage = cast(StartMessage) message;

    if(playerSide == startMessage.getNextState().side)
    {
        //It's our turn, let's do something...
        debug stderr.writeln("Outputing default first move of hole ");
        server.send(new MoveMessage(Hole.SEVEN));
        awaitMessage = true;
    }
    else
    {
        message = server.receive();
        while(message is null)
        {
            //loop....
            message = server.receive();
        }
        awaitMessage = false;
        //Do something? Idk, up to you...

        if(message.getNextState().side != playerSide)
        {
            send(new SwapMessage());
        }

    }

    if(awaitMessage)
    {
        //Get first message that continues the game itself...
        message = server.receive();
        while(message is null)
        {
            message = server.receive();
        }

        if(message.getPhase() == Phase.END)
        {
            return;
        }
    }

    auto mctThread = spawnLinked(&execute, message.getNextState());

    GameState latestState = message.getNextState();
    bool done = false;
    while(!done)
    {
        if(latestState.side == playerSide)
        {
            Thread.sleep(5.seconds);

            mctThread.send(GetBestMove());
            Move move;
            receive((Move message) {
                        move = message;
                    },
                    (NoMoves message) {
                        //There are no moves... oops...
                        //Choose random valid move...
                        Move[] moves = latestState.getMyValidMoves();
                        ulong randMoveIndex = uniform(0, moves.length);
                        move = moves[randMoveIndex];

                        stderr.writeln("Playing random move...");
                        stderr.writeln("No move found...");
                        //stderr.writeln(state.toString());
                        //done = true;
                        //exit(0);
                    });

            mctThread.send(move);
            server.send(new MoveMessage(move.hole));
        }

        //Get Message...
        message = server.receive();
        while(message is null)
        {
            message = server.receive();
        }

        latestState = message.getNextState();

        //Check for game end...
        if(message.getPhase() == Phase.END && !(cast(EndMessage) message))
        {
            //Game has ended, look for end-game move
            message = server.receive();
            while(message is null)
            {
                message = server.receive();
            }

            if(cast(EndMessage) message)
            {
                //We be done, bitches...
                exit(0);
            } 
        }
        else if(cast(EndMessage) message)
        {
            //we be done, bitches...
            exit(0);
        }

        mctThread.send(latestState);

    }
}//*/
