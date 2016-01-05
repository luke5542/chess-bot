import std.stdio;
import std.conv;
import std.string;
import std.exception;
import std.algorithm;
import std.typecons;

import core.exception : RangeError;

enum Color {WHITE, BLACK};
enum PieceType {QUEEN, KING, BISHOP, KNIGHT, ROOK, PAWN};

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
    Color side;       //Who makes the move
    Piece piece;      //Which piece was moved
    byte start_row;  //From where
    byte start_column;
    byte dest_row;   //To where
    byte dest_column;
    
    bool isCastle = false; //used if we need to effectively move two pieces
    byte start_row_rook;  //From where
    byte start_column_rook;
    byte dest_row_rook;   //To where
    byte dest_column_rook;
    
    //@disable this();

    this(Color s, Piece p, byte sr, byte sc, byte dr, byte dc) 
    {
        side = s;
        piece = p;
        start_row = sr;
        dest_row = dr;
        start_column = sc;
        dest_column = dc;
    }
    
    this(Color s, Piece p, byte sr, byte sc, byte dr, byte dc,
            byte srr, byte scr, byte drr, byte dcr) 
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

enum PlayState {PLAYING, WHITE_WIN, BLACK_WIN, TIE}

struct GameState
{
    Tile[8][8] board;
    Color side; // Color who is curerntly playing
    byte movesSinceCaptureOrPawn = 0;
    bool[2] hasKingBeenChecked;
    bool[2] isKingInCheck;
    
    PlayState currentState = PlayState.PLAYING;

    void init()
    {
        hasKingBeenChecked[Color.WHITE] = false;
        hasKingBeenChecked[Color.BLACK] = false;
        isKingInCheck[Color.WHITE] = false;
        isKingInCheck[Color.BLACK] = false;
        side = Color.WHITE;
        
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
            board[t][6].piece = Piece(PieceType.PAWN, Color.BLACK, false);
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
    
    
    GameState performMove(Move move)
    {
        return performMove(move, true);
    }

    //Performs a move given a move and a state
    GameState performMove(Move move, bool updatePlayState)
    {
        GameState newState;
        
        if(move.piece.type != PieceType.PAWN
            && board[move.dest_column][move.dest_row].isEmpty)
        {
            newState.movesSinceCaptureOrPawn = cast(byte) (movesSinceCaptureOrPawn + 1);
        }
        else
        {
            newState.movesSinceCaptureOrPawn = 0;
        }
        
        newState.board = board.dup;
        newState.board[move.start_column][move.start_row].isEmpty = true;
        newState.board[move.dest_column][move.dest_row].isEmpty = false;
        newState.board[move.dest_column][move.dest_row].piece = newState.board[move.start_column][move.start_row].piece;
        
        
        newState.side = side.opposite;
        
        newState.setIsInCheck(Color.WHITE);
        newState.setIsInCheck(Color.BLACK);
        
        if(updatePlayState)
        {
            if(newState.movesSinceCaptureOrPawn >= 50)
            {
                newState.currentState = PlayState.TIE;
            }
            else if(newState.isKingInCheck[newState.side])
            {
                if(newState.getValidMoves(newState.side).length == 0)
                    newState.currentState = (newState.side == Color.WHITE ? PlayState.BLACK_WIN : PlayState.WHITE_WIN);
            }
            else
            {
                newState.currentState = PlayState.PLAYING;
            }
        }
        else
        {
            newState.currentState = currentState;
        }
        
        return newState;
    }
    
    void setIsInCheck(Color side)
    {
        //Get the possible moves for this side and see if any of
        //of them can attack the opposing king. If so, set 
        //that king to being in check.
        Color opposite = side.opposite();
        isKingInCheck[opposite] = false;
        foreach(move; getMoves(side))
        {
            if(!board[move.dest_column][move.dest_row].isEmpty
                && board[move.dest_column][move.dest_row].piece.color == opposite
                && board[move.dest_column][move.dest_row].piece.type == PieceType.KING)
            {
                //King is in check...
                isKingInCheck[opposite] = true;
                hasKingBeenChecked[opposite] = true;
                return;
            }
        }
    }
    
    Move[] getMoves(byte x, byte y)
    {
        if(!board[x][y].isEmpty)
        {
            return getMoves(board[x][y], x, y);
        }
        
        return null;
    }
    
    //Returns a dynamic array of Move structs that are valid from the current state
    Move[] getMoves(Color side)
    {
        Move[] possibleMoves;
        foreach(byte c, tiles; board)
        {
            foreach(byte r, tile; tiles)
            {
                if(tile.isEmpty || tile.piece.color != side)
                {
                    continue;
                }
                
                possibleMoves ~= getMoves(tile, c, r);
            }
        }
        
        return possibleMoves;
    }
    
    Move[] getMoves(Tile tile, byte c, byte r)
    {
        final switch(tile.piece.type)
        {
            case PieceType.QUEEN:
                return getQueenMoves(tile, c, r);
            case PieceType.KING:
                return getKingMoves(tile, c, r);
            case PieceType.BISHOP:
                return getBishopMoves(tile, c, r);
            case PieceType.KNIGHT:
                return getKnightMoves(tile, c, r);
            case PieceType.ROOK:
                return getRookMoves(tile, c, r);
            case PieceType.PAWN:
                return getPawnMoves(tile, c, r);
        }
    }
    
    Move[] getValidMoves(Color side)
    {
        return checkIfIsInCheck(side, getMoves(side));
    }
    
    Move[] getQueenMoves(Tile tile, byte c, byte r)
    {
        return getBishopMoves(tile, c, r) ~ getRookMoves(tile, c, r);
    }
    
    Move[] getKingMoves(Tile tile, byte c, byte r)
    {
        Move[] moves;
        for(byte x = cast(byte)(c - 1); x >= 0 && x < 8; x++)
        {
            for(byte y = cast(byte)(r - 1); y >= 0 && y < 8; y++)
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
        for(byte x = c; x < 8; x++)
        {
            for(byte y = r; y < 8; y++)
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
        for(byte x = c; x >= 0; x--)
        {
            for(byte y = r; y >= 0; y--)
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
        for(byte x = c; x < 8; x++)
        {
            for(byte y = r; y >= 0; y--)
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
        for(byte x = c; x >= 0; x--)
        {
            for(byte y = r; y < 8; y++)
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
            if(checkIfTileEmpty(tile.piece.color, cast(byte) pair[0], cast(byte) pair[1]))
            {
                moves ~= Move(tile.piece.color, tile.piece, r, c, cast(byte) pair[1], cast(byte) pair[0]);
            }
        }
        
        return moves;
    }
    
    Move[] getRookMoves(Tile tile, byte c, byte r)
    {
        Move[] moves;
        //Horizontal moves
        for(byte x = cast(byte)(c - 1); x >= 0; x--)
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
        for(byte x = cast(byte)(c + 1); x < 8; x++)
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
        for(byte y = cast(byte)(r - 1); y >= 0; y--)
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
        for(byte y = cast(byte)(r + 1); y < 8; y++)
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
        byte row1, row2;
        if(tile.piece.color == Color.WHITE)
        {
            row1 = cast(byte)(r + 1);
            row2 = cast(byte)(r + 2);
        }
        else //is black
        {
            row1 = cast(byte)(r - 1);
            row2 = cast(byte)(r - 2);
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
        if(c < 8 && c >= 0 && r < 8 && r >= 0)
            return board[c][r].isEmpty || board[c][r].piece.color != side;
        else
            return false;
    }
    
    Move[] checkIfIsInCheck(Color side, Move[] moves)
    {
        Move[] verifiedMoves;
        //Need to make sure moves leave the player without check
        foreach(move; moves)
        {
            auto newState = performMove(move, false);
            if(!newState.isKingInCheck[side])
            {
                verifiedMoves ~= move;
            }
        }
        
        return verifiedMoves;
    }
    
    Move[] getMyValidMoves()
    {
      return getValidMoves(this.side);
    }
    
    bool isWinner(Color sideToCheck)
    {
        return (currentState == PlayState.WHITE_WIN && sideToCheck == Color.WHITE)
                || (currentState == PlayState.BLACK_WIN && sideToCheck == Color.BLACK);
    }
    
}