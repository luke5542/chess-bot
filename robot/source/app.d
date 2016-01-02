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

enum MessageType {PLAY_GAME};

void main(string[] args)
{
    version(unittest)
    {
        writeln("Done running Unit Tests.");
    }
    else
    {
        playGameWithServer();
    }
}

void playGameWithServer()
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
}

void playGameInGui()
{
    //auto botThread = spawnLinked(&execute, message.getNextState());
    
    Tid guiThread = spawnLinked(&runGui);
    Tid botThread;
    
    bool isDone = false;
    bool isPlayingGame = false;
    GameState state;
    while(!isDone)
    {
        receiveTimeout( 1.usecs,
                        (MessageType message) {
                            switch(message)
                            {
                                case PLAY_GAME:
                                    isPlayingGame = true;
                                    state.init();
                                    botThread = spawnLinked(&runBot, state, );
                                    break;
                            }
                        });
    }
}
