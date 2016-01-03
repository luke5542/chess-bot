import std.stdio;
import std.c.stdlib;
import std.concurrency;
import std.random;
import std.conv;

import dsfml.system;
import dsfml.graphics;
import dsfml.window;

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

void runGui()
{
    GameGUI gui = new GameGUI();
    gui.run();
}

enum GuiState {MENU, PLAYING};

class GameGUI
{

    private
    {
        RenderWindow m_window;
        bool m_gameOver = false;

        RectangleShape[8][8] board;
        Sprite[8][8] pieces;
        Texture[PieceType] whitePieces;
        Texture[PieceType] blackPieces;
        GuiState currentState = GuiState.MENU;
        PieceColor mySide;
        
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
        
        //TODO set a new View to be the 'camera'
        
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
        foreach(x, column; board)
        {
            foreach(y, ref tile; column)
            {
                tile = new RectangleShape();
                tile.position = Vector2f(x*10, y*10);
                tile.size = Vector2f(10, 10);
                if((y % 2 == 0 && x % 2 == 0) || (y % 2 != 0 && x % 2 != 0))
                {
                    //Brown
                    tile.fillColor = DsfmlColor(153, 102, 51);
                }
                else
                {
                    //Beige
                    tile.fillColor = DsfmlColor(230, 204, 179);
                }
            }
        }
        
        //TODO initialize pieces for given state...
        loadPieceTextures();
        foreach(x, column; pieces)
        {
            foreach(y, ref sprite; column)
            {
                if(!startState.board[x][y].isEmpty)
                {
                    if(startState.board[x][y].piece.color == PieceColor.WHITE)
                    {
                        sprite = new Sprite(whitePieces[startState.board[x][y].piece.type]);
                    }
                    else
                    {
                        sprite = new Sprite(blackPieces[startState.board[x][y].piece.type]);
                    }
                    sprite.position = Vector2f(x*10, y*10);
                }
            }
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
        if (!whitePieces[PieceType.PAWN].loadFromFile(PAWN_TEXTURE_WHITE)
            && !whitePieces[PieceType.ROOK].loadFromFile(ROOK_TEXTURE_WHITE)
            && !whitePieces[PieceType.KNIGHT].loadFromFile(KNIGHT_TEXTURE_WHITE)
            && !whitePieces[PieceType.BISHOP].loadFromFile(BISHOP_TEXTURE_WHITE)
            && !whitePieces[PieceType.QUEEN].loadFromFile(QUEEN_TEXTURE_WHITE)
            && !whitePieces[PieceType.KING].loadFromFile(KING_TEXTURE_WHITE)) {
            exit(-1);
        }
            
        blackPieces[PieceType.PAWN] = new Texture();
        blackPieces[PieceType.ROOK] = new Texture();
        blackPieces[PieceType.KNIGHT] = new Texture();
        blackPieces[PieceType.BISHOP] = new Texture();
        blackPieces[PieceType.QUEEN] = new Texture();
        blackPieces[PieceType.KING] = new Texture();
        if (!blackPieces[PieceType.PAWN].loadFromFile(PAWN_TEXTURE_BLACK)
            && !blackPieces[PieceType.ROOK].loadFromFile(ROOK_TEXTURE_BLACK)
            && !blackPieces[PieceType.KNIGHT].loadFromFile(KNIGHT_TEXTURE_BLACK)
            && !blackPieces[PieceType.BISHOP].loadFromFile(BISHOP_TEXTURE_BLACK)
            && !blackPieces[PieceType.QUEEN].loadFromFile(QUEEN_TEXTURE_BLACK)
            && !blackPieces[PieceType.KING].loadFromFile(KING_TEXTURE_BLACK)) {
            exit(-1);
        }
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
                break;
        }
    }

    void draw(ref RenderWindow window)
    {
        window.clear();
        
        final switch(currentState)
        {
            case GuiState.MENU:
                window.draw(playButton);
                break;
            case GuiState.PLAYING:
                foreach(column; board)
                {
                    foreach(tile; column)
                    {
                        window.draw(tile);
                    }
                }
                foreach(column; pieces)
                {
                    foreach(piece; column)
                    {
                        window.draw(piece);
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

}
