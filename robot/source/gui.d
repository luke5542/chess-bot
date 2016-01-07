import std.stdio;
import std.c.stdlib;
import std.concurrency;
import std.random;
import std.conv;
import std.typecons;
import core.time;

import dsfml.system;
import dsfml.graphics;
import dsfml.window;

import animate.d;

import gamestate;
import app;

immutable WINDOW_HEIGHT = 800;
immutable WINDOW_WIDTH  = 1200;

immutable PAWN_TEXTURE_WHITE = "./assets/white_pawn.png";
immutable ROOK_TEXTURE_WHITE = "./assets/white_rook.png";
immutable KNIGHT_TEXTURE_WHITE = "./assets/white_knight.png";
immutable BISHOP_TEXTURE_WHITE = "./assets/white_bishop.png";
immutable QUEEN_TEXTURE_WHITE = "./assets/white_queen.png";
immutable KING_TEXTURE_WHITE = "./assets/white_king.png";

immutable PAWN_TEXTURE_BLACK = "./assets/black_pawn.png";
immutable ROOK_TEXTURE_BLACK = "./assets/black_rook.png";
immutable KNIGHT_TEXTURE_BLACK = "./assets/black_knight.png";
immutable BISHOP_TEXTURE_BLACK = "./assets/black_bishop.png";
immutable QUEEN_TEXTURE_BLACK = "./assets/black_queen.png";
immutable KING_TEXTURE_BLACK = "./assets/black_king.png";

immutable TEXT_FONT_LOC = "./assets/Roboto-Bold.ttf";

alias DsfmlColor = dsfml.graphics.color.Color;
alias PieceColor = gamestate.Color;

DsfmlColor highlightTextColor = DsfmlColor(107, 44, 145);
DsfmlColor normalTextColor = DsfmlColor(0, 0, 0);
DsfmlColor selectedColor = DsfmlColor(51, 204, 0);
DsfmlColor validMoveColor = DsfmlColor(0, 58, 230);
DsfmlColor brownTile = DsfmlColor(153, 102, 51);
DsfmlColor beigeTile = DsfmlColor(230, 204, 179);

auto botMoveDuration = seconds(2);

void runGui()
{
    GameGUI gui = new GameGUI();
    gui.run();
}

enum GuiState {MENU, PLAYING};

immutable TILE_SIZE = 50;
immutable TILE_OFFSET = Vector2f((WINDOW_WIDTH - 400)/2, (WINDOW_HEIGHT - 400)/2);

class GameGUI
{

    private
    {
        RenderWindow m_window;
        bool m_gameOver = false;

        RectangleShape[8][8] boardTiles;
        Sprite[8][8] pieces;
        Texture[PieceType] whitePieces;
        Texture[PieceType] blackPieces;
        GuiState currentState = GuiState.MENU;
        PieceColor mySide;
        Move[] selectedMoves;
        SimpleAnimation botMoveTimer;
        
        Text playButton;
        Font font;
    }
    
    @property
    {
        bool gameOver(bool over)
        {
            m_gameOver = over;
            return m_gameOver;
        }
        
        bool gameOver()
        {
            return m_gameOver;
        }
    }

    this()
    {
        auto settings = ContextSettings();
        settings.antialiasingLevel = 8;
        m_window = new RenderWindow(VideoMode(WINDOW_WIDTH, WINDOW_HEIGHT), "Chess", Window.Style.DefaultStyle, settings);
        m_window.setFramerateLimit(30);
        
        initializeMenu();
    }
    
    void initializeMenu()
    {
        font = new Font();
        if(!font.loadFromFile(TEXT_FONT_LOC))
        {
            writeln("Failed to load font file! Exiting...");
            exit(1);
        }
        playButton = new Text("Play Against Bot", font, 80);
        playButton.position = Vector2f(WINDOW_WIDTH/2, WINDOW_HEIGHT/2 - 200);
        playButton.origin = Vector2f(playButton.getLocalBounds().width/2,
                                        playButton.getLocalBounds().height/2);
    }
    
    void initializeGameBoard(const GameState startState, bool myTurn)
    {
        mySide = myTurn ? startState.side : startState.side.opposite;
        //initialize the board
        for(int x = 0; x < 8; x++)
        {
            for(int y = 0; y < 8; y++)
            {
                auto tile = new RectangleShape();
                tile.position = getPiecePosition(x, y);
                tile.size = Vector2f(TILE_SIZE, TILE_SIZE);
                tile.origin = Vector2f(TILE_SIZE/2, TILE_SIZE/2);
                setTileColor(tile, x, y);
                
                boardTiles[x][y] = tile;
            }
        }
        
        //TODO initialize pieces for given state...
        loadPieceTextures();
        for(int x = 0; x < 8; x++)
        {
            for(int y = 0; y < 8; y++)
            {
                if(!startState.board[x][y].isEmpty)
                {
                    auto index = startState.board[x][y].piece.type;
                    if(startState.board[x][y].piece.color == PieceColor.WHITE)
                    {
                        pieces[x][y] = new Sprite(whitePieces[index]);
                        auto size = whitePieces[index].getSize();
                        pieces[x][y].origin = Vector2f(size.x/2, size.y/2);
                    }
                    else
                    {
                        pieces[x][y] = new Sprite(blackPieces[index]);
                        auto size = blackPieces[index].getSize();
                        pieces[x][y].origin = Vector2f(size.x/2, size.y/2);
                    }
                    pieces[x][y].position = getPiecePosition(x, y);
                }
            }
        }
    }
    
    Vector2f getPiecePosition(int x, int y)
    {
        return Vector2f(TILE_OFFSET.x + x * TILE_SIZE, TILE_OFFSET.y + y * TILE_SIZE);
    }
    
    void setTileColor(Shape tile, int x, int y)
    {
        if((y % 2 == 1 && x % 2 == 0) || (y % 2 != 1 && x % 2 != 0))
        {
            tile.fillColor = brownTile;
        }
        else
        {
            tile.fillColor = beigeTile;
        }
    }
    
    void loadPieceTextures()
    {
        whitePieces[PieceType.PAWN] = new Texture();
        whitePieces[PieceType.ROOK] = new Texture();
        whitePieces[PieceType.KNIGHT] = new Texture();
        whitePieces[PieceType.BISHOP] = new Texture();
        whitePieces[PieceType.QUEEN] = new Texture();
        whitePieces[PieceType.KING] = new Texture();
        if(!whitePieces[PieceType.PAWN].loadFromFile(PAWN_TEXTURE_WHITE))
            exit(-1);
        if(!whitePieces[PieceType.ROOK].loadFromFile(ROOK_TEXTURE_WHITE))
            exit(-1);
        if(!whitePieces[PieceType.KNIGHT].loadFromFile(KNIGHT_TEXTURE_WHITE))
            exit(-1);
        if(!whitePieces[PieceType.BISHOP].loadFromFile(BISHOP_TEXTURE_WHITE))
            exit(-1);
        if(!whitePieces[PieceType.QUEEN].loadFromFile(QUEEN_TEXTURE_WHITE))
            exit(-1);
        if(!whitePieces[PieceType.KING].loadFromFile(KING_TEXTURE_WHITE))
            exit(-1);
            
        blackPieces[PieceType.PAWN] = new Texture();
        blackPieces[PieceType.ROOK] = new Texture();
        blackPieces[PieceType.KNIGHT] = new Texture();
        blackPieces[PieceType.BISHOP] = new Texture();
        blackPieces[PieceType.QUEEN] = new Texture();
        blackPieces[PieceType.KING] = new Texture();
        if(!blackPieces[PieceType.PAWN].loadFromFile(PAWN_TEXTURE_BLACK))
            exit(-1);
        if(!blackPieces[PieceType.ROOK].loadFromFile(ROOK_TEXTURE_BLACK))
            exit(-1);
        if(!blackPieces[PieceType.KNIGHT].loadFromFile(KNIGHT_TEXTURE_BLACK))
            exit(-1);
        if(!blackPieces[PieceType.BISHOP].loadFromFile(BISHOP_TEXTURE_BLACK))
            exit(-1);
        if(!blackPieces[PieceType.QUEEN].loadFromFile(QUEEN_TEXTURE_BLACK))
            exit(-1);
        if(!blackPieces[PieceType.KING].loadFromFile(KING_TEXTURE_BLACK))
            exit(-1);
    }

    void run()
    {
        //For event polling...
        Event event;

        Clock clock = new Clock();

        while (m_window.isOpen())
        {
            // check all the m_window's events that were triggered since the last iteration of the loop
            while(m_window.pollEvent(event))
            {
                // "close requested" event: we close the m_window
                if(event.type == Event.EventType.Closed)
                {
                    m_window.close();
                }
                else if(event.type == Event.EventType.KeyPressed)
                {
                    handleKeyboard(event);
                }
                else if(event.type == Event.EventType.MouseButtonReleased)
                {
                    handleMouse(event.mouseButton);
                }
            }

            Duration time = clock.getElapsedTime();
            clock.restart();
            
            update(m_window, time);
            draw(m_window);
        }
    }

    bool handleKeyboard(Event event)
    {
        if(event.key.code == Keyboard.Key.Escape)
        {
            //TODO exit(0);
            return true;
        }

        return false;
    }

    void handleMouse(Event.MouseButtonEvent mouseButton)
    {
        if(mouseButton.button == Mouse.Button.Left)
        {
            auto mouseLoc = Mouse.getPosition(m_window);
            if(currentState == GuiState.MENU)
            {
                if(playButton.getGlobalBounds().contains(mouseLoc))
                {
                    setupBotAndBeginGame(this);
                }
            }
            else if(currentState == GuiState.PLAYING)
            {
                Tuple!(int, int) selectedLoc;
                selectedLoc[0] = -1;
                selectedLoc[1] = -1;
                foreach(int x, column; boardTiles)
                {
                    foreach(int y, tile; column)
                    {
                        if(tile !is null)
                        {
                            int i = -1;
                            if(pieces[x][y] !is null && isMyPiece(x, y)
                                && tile.getGlobalBounds.contains(mouseLoc))
                            {
                                tile.fillColor = selectedColor;
                                selectedLoc[0] = x;
                                selectedLoc[1] = y;
                            }
                            else if(tile.getGlobalBounds.contains(mouseLoc)
                                    && (i = findMoveFromSelectedPiece(x, y)) >= 0)
                            {
                                writeln("Selected Tile: (", x, ",", y, ")");
                                Move m = selectedMoves[i];
                                writeln("Move found: ", m);
                                updateGuiForMove(m);
                                playMove(m);
                                selectedMoves.length = 0;
                                setTileColor(tile, x, y);
                                
                                botMoveTimer = new SimpleAnimation(botMoveDuration);
                            }
                            else
                            {
                                setTileColor(tile, x, y);
                            }
                        }
                    }
                }
                highlightMoves(selectedLoc);
            }
        }
    }

    void update(ref RenderWindow window, Duration time)
    {
        if(m_gameOver)
        {
            window.close();
        }
        auto mouseLoc = Mouse.getPosition(window);
        final switch(currentState)
        {
            case GuiState.MENU:
                if(playButton.getGlobalBounds().contains(mouseLoc))
                {
                    playButton.setColor(highlightTextColor);
                }
                else
                {
                    playButton.setColor(normalTextColor);
                }
                checkMessages(this);
                break;
            case GuiState.PLAYING:
                checkMessages(this);
                if(botMoveTimer !is null)
                {
                    botMoveTimer.update(time);
                    if(!botMoveTimer.isRunning())
                    {
                        botMoveTimer = null;
                        requestBotMove();
                    }
                }
                break;
        }
    }

    void draw(ref RenderWindow window)
    {
        window.clear(DsfmlColor(77, 77, 255));
        
        final switch(currentState)
        {
            case GuiState.MENU:
                window.draw(playButton);
                break;
            case GuiState.PLAYING:
                foreach(column; boardTiles)
                {
                    foreach(tile; column)
                    {
                        if(tile !is null)
                        {
                            window.draw(tile);
                        }
                    }
                }
                foreach(column; pieces)
                {
                    foreach(piece; column)
                    {
                        if(piece !is null)
                        {
                            window.draw(piece);
                        }
                    }
                }
                break;
        }

        window.display();
    }
    
    void playGame()
    {
        currentState = GuiState.PLAYING;
    }
    
    void highlightMoves(Tuple!(int, int) selectedPiece)
    {
        if(selectedPiece[0] < 0 || selectedPiece[1] < 0)
            return;
        
        writeln("Selected Piece: ", selectedPiece, ", ", getPiecePosition(selectedPiece[0], selectedPiece[1]));
        selectedMoves = getMovesForLoc(selectedPiece[0], selectedPiece[1]);
        foreach(move; selectedMoves)
        {
            auto tile = boardTiles[move.dest_column][move.dest_row];
            tile.fillColor = validMoveColor;
        }
    }
    
    //Returns the index of the move, or -1 if it doesn't exist
    int findMoveFromSelectedPiece(int x, int y)
    {
        foreach(int i, move; selectedMoves)
        {
            if(move.dest_column == x && move.dest_row == y)
            {
                writeln("Move found: ", i, ", ", move);
                return i;
            }
        }
        
        return -1;
    }
    
    void updateGuiForMove(Move m)
    {
        writeln("Gui updating with move: ", m);
        pieces[m.dest_column][m.dest_row] = pieces[m.start_column][m.start_row];
        pieces[m.start_column][m.start_row] = null;
        pieces[m.dest_column][m.dest_row].position = getPiecePosition(m.dest_column, m.dest_row);
        
        if(m.isCastle)
        {
            pieces[m.dest_column_rook][m.dest_row_rook] = pieces[m.start_column_rook][m.start_row_rook];
            pieces[m.start_column_rook][m.start_row_rook] = null;
            pieces[m.dest_column_rook][m.dest_row_rook].position = getPiecePosition(m.dest_column_rook, m.dest_row_rook);
        }
    }

}