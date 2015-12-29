import std.concurrency;
import std.stdio;
import std.conv;
import core.time;

struct Exit {}

void wasteCPU(long timeToWait)
{
    auto time = TickDuration.currSystemTick();
    auto deltaT = time;
    ownerTid.send("Starting infinite loop for: " ~ to!string(timeToWait) ~ " milliseconds.");
    bool done = false;
    while(!done)
    {
        deltaT = TickDuration.currSystemTick() - time;
        if(deltaT.msecs > timeToWait)
        {
            done = true;
            ownerTid.send(Exit());
        }
    }
}

void wasteAllCPU()
{
    bool done = false;
    long count;
    while(!done)
    {
        count++;
        if(count > 10000)
        {
            count = 0;
            receiveTimeout( 1.usecs,
                            (Exit message) {
                                stderr.writeln("Exiting");
                                done = true;
                            });
        }
    }
}

void testIdle()
{
    bool done = false;
    auto time = TickDuration.currSystemTick();
    spawn(&wasteCPU, 10000);
    while(!done)
    {
        auto deltaT = TickDuration.currSystemTick() - time;
        if(deltaT.usecs() > 100.msecs.total!"usecs")
        {
            writeln("nothing found yet...");
            receiveTimeout( 1.msecs,
                            (Exit message) {
                                writeln("Exiting");
                                done = true;
                            },
                            (string message) {
                                  writeln("received: ", message);
                            });

            time = TickDuration.currSystemTick();
        }
    }
}