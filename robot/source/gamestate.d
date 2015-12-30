import std.stdio;
import std.conv;
import std.string;
import std.exception;
import std.algorithm;

import core.exception : RangeError;

enum Color {WHITE, BLACK};
enum PieceType {QUEEN, KING, BISHOP, KNIGHT, ROOK, PAWN};
enum Row {ONE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT};
enum Column {A, B, C, D, E, F, G, H};

//Helper function for fancy side changing
Color opposite(Color s)
{
    return s == Color.WHITE ? Color.BLACK : Color.WHITE;
}

struct Piece
{
    PieceType type;
    Color color;
    bool hasMoved = false;
}

struct Tile
{
    Color tileColor;
    Piece piece;
    bool isEmpty = true;
}

struct Move
{
    Color   side;       //Who makes the move
    Piece   piece;      //Which piece was moved
    Row     start_row;  //From where
    Column  start_column;
    Row     dest_row;   //To where
    Column  dest_column;
    
    bool isCastle = false; //used if we need to effectively move two pieces
    Row     start_row_rook;  //From where
    Column  start_column_rook;
    Row     dest_row_rook;   //To where
    Column  dest_column_rook;
    
    @disable this();

    this(Color s, Piece p, Row sr, Column sc, Row dr, Column dc) 
    {
        side = s;
        piece = p;
        start_row = sr;
        dest_row = dr;
        start_column = sc;
        dest_column = dc;
    }
    
    this(Color s, Piece p, Row sr, Column sc, Row dr, Column dc,
            Row srr, Column scr, Row drr, Column dcr) 
    {
        side = s;
        piece = p;
        start_row = sr;
        dest_row = dr;
        start_column = sc;
        dest_column = dc;
        
        isCastle = true;
        start_row_rook = srr;
        dest_row_rook = drr;
        start_column_rook = scr;
        dest_column_rook = dcr;
    }

    string toString() 
    {
        return "Move: Color = " ~ to!string(side) ~ ", Piece = " ~ to!string(piece)
             ~ ", (" ~ to!string(start_column) ~ ", " ~ to!string(start_row) ~ ")"
             ~ ", (" ~ to!string(dest_column) ~ ", " ~ to!string(dest_row) ~ ")";
    }
}

struct GameState
{
    Tile[8][8] board;
    Color side; // Color who is curerntly playing
    byte movesSinceCaptureOrPawn = 0;
    bool[Color] hasKingBeenChecked;
    bool[Color] isKingInCheck;
    
    enum PlayState {PLAYING, WHITE_WIN, BLACK_WIN, TIE}
    PlayState currentState = PLAYING;

    GameState init()
    {
        hasKingBeenChecked[Color.WHITE] = false;
        hasKingBeenChecked[Color.BLACK] = false;
        isKingInCheck[Color.WHITE] = false;
        isKingInCheck[Color.BLACK] = false;
        side = WHITE;
        
        for(int c = 0; c < 8; c++)
        {
            for(int r = 0; r < 8; r++)
            {
                if(r % 2 == 0) //is even
                {
                    board[c][r].tileColor = (c % 2 == 0 ? Color.BLACK : Color.WHITE);
                }
                else //is odd
                {
                    board[c][r].tileColor = (c % 2 == 0 ? Color.WHITE : Color.BLACK);
                }
            }
        }
        //Set the pawns
        for(int t = 0; t < 8; t++)
        {
            board[t][1].piece = Piece(PieceType.PAWN, Color.WHITE, false);
            board[t][6].piece = Piece(PieceType.PAWN, Color.WHITE, false);
            board[t][1].isEmpty = false;
            board[t][6].isEmpty = false;
        }
        
        //Rooks
        board[0][0].piece = Piece(PieceType.ROOK, Color.WHITE, false);
        board[7][0].piece = Piece(PieceType.ROOK, Color.WHITE, false);
        board[0][7].piece = Piece(PieceType.ROOK, Color.BLACK, false);
        board[7][7].piece = Piece(PieceType.ROOK, Color.BLACK, false);
        board[0][0].isEmpty = false;
        board[7][0].isEmpty = false;
        board[0][7].isEmpty = false;
        board[7][7].isEmpty = false;
        
        //Knights
        board[1][0].piece = Piece(PieceType.KNIGHT, Color.WHITE, false);
        board[6][0].piece = Piece(PieceType.KNIGHT, Color.WHITE, false);
        board[1][7].piece = Piece(PieceType.KNIGHT, Color.BLACK, false);
        board[6][7].piece = Piece(PieceType.KNIGHT, Color.BLACK, false);
        board[1][0].isEmpty = false;
        board[6][0].isEmpty = false;
        board[1][7].isEmpty = false;
        board[6][7].isEmpty = false;
        
        //Bishops
        board[2][0].piece = Piece(PieceType.BISHOP, Color.WHITE, false);
        board[5][0].piece = Piece(PieceType.BISHOP, Color.WHITE, false);
        board[2][7].piece = Piece(PieceType.BISHOP, Color.BLACK, false);
        board[5][7].piece = Piece(PieceType.BISHOP, Color.BLACK, false);
        board[2][0].isEmpty = false;
        board[5][0].isEmpty = false;
        board[2][7].isEmpty = false;
        board[5][7].isEmpty = false;
        
        //Queens
        board[3][0].piece = Piece(PieceType.QUEEN, Color.WHITE, false);
        board[3][7].piece = Piece(PieceType.QUEEN, Color.BLACK, false);
        board[3][0].isEmpty = false;
        board[3][7].isEmpty = false;
        
        //Kings
        board[4][0].piece = Piece(PieceType.KING, Color.WHITE, false);
        board[4][7].piece = Piece(PieceType.KING, Color.BLACK, false);
        board[4][0].isEmpty = false;
        board[4][7].isEmpty = false;
        
    }

    //Performs a move given a move and a state
    GameState performMove(Move move)
    {
        //TODO
        
        setIsInCheck(Color.WHITE);
        setIsInCheck(Color.BLACK);
    }
    
    void setIsInCheck(Color side)
    {
        //Get the possible moves for this side and see if any of
        //of them can attack the opposing king. If so, set 
        //that king to being in check.
        Color opposite = side.opposite();
        foreach(move; getValidMoves(side))
        {
            if(!board[move.dest_column][move.dest_row].isEmpty
                && board[move.dest_column][move.dest_row].piece.color == opposite
                && board[move.dest_column][move.dest_row].piece.type == PieceType.KING)
            {
                //King is in check...
                isKingInCheck[opposite] = true;
                return;
            }
        }
    }
    
    //Returns a dynamic array of Move structs that are valid from the current state
    Move[] getValidMoves(Color side)
    {
        Move[] validMoves;
        foreach(c, tiles; board)
        {
            foreach(r, tile; tiles)
            {
                if(tile.isEmpty || tile.piece.color != side)
                {
                    continue;
                }
                
                final switch(tile.piece.type)
                {
                    case QUEEN:
                        validMoves ~= getQueenMoves(tile, c, r);
                        break;
                    case KING:
                        validMoves ~= getKingMoves(tile, c, r);
                        break;
                    case BISHOP:
                        validMoves ~= getBishopMoves(tile, c, r);
                        break;
                    case KNIGHT:
                        validMoves ~= getKnightMoves(tile, c, r);
                        break;
                    case ROOK:
                        validMoves ~= getRookMoves(tile, c, r);
                        break;
                    case PAWN:
                        validMoves ~= getPawnMoves(tile, c, r);
                        break;
                }
            }
        }
        
        return checkIfIsInCheck(side, validMoves);
    }
    
    Move[] getQueenMoves(Tile tile, byte c, byte r)
    {
        return getBishopMoves(tile, c, r) ~ getRookMoves(tile, c, r);
    }
    
    Move[] getKingMoves(Tile tile, byte c, byte r)
    {
        Move[] moves;
        for(int x = c - 1; x >= 0 && x < 8; x++)
        {
            for(int y = r - 1; y >= 0 && y < 8; y++)
            {
                if(checkIfTileEmpty(tile.piece.color, x, y))
                {
                    moves ~= Move(tile.piece.color, tile.piece, r, c, y, x);
                }
            }
        }
        
        //TODO prevent castling through check...
        if(!tile.piece.hasMoved && !hasKingBeenChecked[tile.piece.color])
        {
            if(tile.piece.color == Color.WHITE)
            {
                if(board[0][0].piece.type == PieceType.ROOK
                    && !board[0][0].piece.hasMoved
                    && board[1][0].isEmpty
                    && board[2][0].isEmpty
                    && board[3][0].isEmpty)
                {
                    moves ~= Move(tile.piece.color, tile.piece, r, c, 0, 2, 0, 0, 0, 3);
                }
                if(board[7][0].piece.type == PieceType.ROOK
                    && !board[7][0].piece.hasMoved
                    && board[6][0].isEmpty
                    && board[5][0].isEmpty)
                {
                    moves ~= Move(tile.piece.color, tile.piece, r, c, 0, 6, 0, 7, 0, 5);
                }
            }
            else
            {
                if(board[0][7].piece.type == PieceType.ROOK
                    && !board[0][7].piece.hasMoved
                    && board[1][7].isEmpty
                    && board[2][7].isEmpty
                    && board[3][7].isEmpty)
                {
                    moves ~= Move(tile.piece.color, tile.piece, r, c, 7, 2, 7, 0, 7, 3);
                }
                if(board[7][7].piece.type == PieceType.ROOK
                    && !board[7][7].piece.hasMoved
                    && board[6][7].isEmpty
                    && board[5][7].isEmpty)
                {
                    moves ~= Move(tile.piece.color, tile.piece, r, c, 7, 6, 7, 7, 7, 5);
                }
            }
        }
        
        return moves;
    }
    
    Move[] getBishopMoves(Tile tile, byte c, byte r)
    {
        Move[] moves;
        for(int x = c; x < 8; x++)
        {
            for(int y = r; y < 8; y++)
            {
                if(checkIfTileEmpty(tile.piece.color, x, y))
                {
                    moves ~= Move(tile.piece.color, tile.piece, r, c, y, x);
                }
                else
                {
                    break;
                }
            }
        }
        for(int x = c; x >= 0; x--)
        {
            for(int y = r; y >= 0; y--)
            {
                if(checkIfTileEmpty(tile.piece.color, x, y))
                {
                    moves ~= Move(tile.piece.color, tile.piece, r, c, y, x);
                }
                else
                {
                    break;
                }
            }
        }
        for(int x = c; x < 8; x++)
        {
            for(int y = r; y >= 0; y--)
            {
                if(checkIfTileEmpty(tile.piece.color, x, y))
                {
                    moves ~= Move(tile.piece.color, tile.piece, r, c, y, x);
                }
                else
                {
                    break;
                }
            }
        }
        for(int x = c; x >= 0; x--)
        {
            for(int y = r; y < 8; y++)
            {
                if(checkIfTileEmpty(tile.piece.color, x, y))
                {
                    moves ~= Move(tile.piece.color, tile.piece, r, c, y, x);
                }
                else
                {
                    break;
                }
            }
        }
        
        return moves;
    }
    
    Move[] getKnightMoves(Tile tile, byte c, byte r)
    {
        Move[] moves;
        Tuple!(int, int)[] pairs;
        Tuple!(int, int) temp;
        temp[0] = c - 2;
        temp[1] = r - 1;
        pairs ~= temp;
        temp[0] = c - 2;
        temp[1] = r + 1;
        pairs ~= temp;
        temp[0] = c + 2;
        temp[1] = r - 1;
        pairs ~= temp;
        temp[0] = c + 2;
        temp[1] = r + 1;
        pairs ~= temp;
        
        temp[0] = c - 1;
        temp[1] = r - 2;
        pairs ~= temp;
        temp[0] = c - 1;
        temp[1] = r + 2;
        pairs ~= temp;
        temp[0] = c + 1;
        temp[1] = r - 2;
        pairs ~= temp;
        temp[0] = c + 1;
        temp[1] = r + 2;
        pairs ~= temp;
        
        foreach(pair; pairs)
        {
            if(pair[0] >= 0 && pair[0] < 8
                && pair[1] >= 0 && pair[1] < 8
                && checkIfTileEmpty(tile.piece.color, pair[0], pair[1]))
            {
                moves ~= Move(tile.piece.color, tile.piece, r, c, pair[1], pair[0]);
            }
        }
    }
    
    Move[] getRookMoves(Tile tile, byte c, byte r)
    {
        Move[] moves;
        //Horizontal moves
        for(int x = c - 1; x >= 0; x--)
        {
            if(checkIfTileEmpty(tile.piece.color, x, r))
            {
                moves ~= Move(tile.piece.color, tile.piece, r, c, r, x);
            }
            else
            {
                break;
            }
        }
        for(int x = c + 1; x < 8; x++)
        {
            if(checkIfTileEmpty(tile.piece.color, x, r))
            {
                moves ~= Move(tile.piece.color, tile.piece, r, c, r, x);
            }
            else
            {
                break;
            }
        }
        
        //Vertical moves
        for(int y = r - 1; y >= 0; y--)
        {
            if(checkIfTileEmpty(tile.piece.color, c, y))
            {
                moves ~= Move(tile.piece.color, tile.piece, r, c, y, c);
            }
            else
            {
                break;
            }
        }
        for(int y = r + 1; y < 8; y++)
        {
            if(checkIfTileEmpty(tile.piece.color, c, y))
            {
                moves ~= Move(tile.piece.color, tile.piece, r, c, y, c);
            }
            else
            {
                break;
            }
        }
        
        return moves;
    }
    
    Move[] getPawnMoves(Tile tile, byte c, byte r)
    {
        Move[] moves;
        int row1, row2;
        if(tile.piece.color == Color.WHITE)
        {
            row1 = r + 1;
            row2 = r + 2;
        }
        else //is black
        {
            row1 = r - 1;
            row2 = r - 2;
        }
        
        if(checkIfTileEmpty(tile.piece.color, c, row1))
        {
            moves ~= Move(tile.piece.color, tile.piece, r, c, row1, c);
            if(!tile.piece.hasMoved && checkIfTileEmpty(tile.piece.color, c, row2))
            {
                moves ~= Move(tile.piece.color, tile.piece, r, c, row2, c);
            }
        }
        
        return moves;
    }
    
    bool checkIfTileEmpty(Color side, int c, int r)
    {
        return board[c][r].isEmpty || board[c][r].piece.color != side;
    }
    
    Move[] checkIfIsInCheck(Color side, Move[] moves)
    {
        Move[] verifiedMoves;
        //Need to make sure moves leave the player without check
        foreach(move; moves)
        {
            auto newState = performMove(move);
            if(!newState.isKingInCheck[side])
            {
                verifiedMoves ~= move;
            }
        }
    }
    
    Move[] getMyValidMoves()
    {
      return getValidMoves(this.side);
    }
    
}
