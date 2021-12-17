package tokenizer
import fmt "core:fmt"
import utf8 "core:unicode/utf8"
import strings "core:strings"
import os "core:os"

Token :: struct{
	type : TokenType,
	data : string,
}

Tokenizer :: struct{
	src : string,
	offset : int,
	last_token : ^Token,
	at : rune,
}

TokenType :: enum{
	Identifier,
    Paren,
    OpenParen,
    CloseParen,
    Asterisk,
    OpenBrace,
    CloseBrace,
    LessThanSign,
    GreaterThanSign,
    String,
    SemiColon,
    Colon,
    Period,
    Dash,
    Underscore,
    Comma,
    EndOfStream,
    Comment,
    Pound,
    ReturnCarriage,
    NewLine,
	ForwardSlash,
	BackwardSlash,
    Pipe,
    Unknown,
}

is_whitespace :: proc(r : rune) -> bool{
	if r == ' '  ||
       r == '\t' ||
       r == '\n' ||
       r == '\r'{
       	return true
    }
    return false
}
is_alpha :: proc(r : rune)-> bool{
	result : bool = ((r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z'))
    return result
}

is_num :: proc(r : rune) -> bool{
    return (r >= '0' && r <= '9') || (r == '-') || (r == '.')
}

is_allowed_in_identifier :: proc(r : rune)-> bool{
    return (r == '_');
}
is_whitespace_no_end_of_line :: proc(r : rune) -> bool{
	if r == ' '  ||
       r == '\t'{
       	return true
    }
    return false
}


is_single_line_comment_c_style_rune :: proc(r : rune,next_r : rune) -> bool{
    return (r == '/' && next_r == '/')
}

is_single_line_comment_lisp_style_rune :: proc(r : rune) -> bool{
    return (r == ';')
}

is_multi_line_comment_start_c_style_rune :: proc(r : rune,next_r : rune)-> bool{
    return (r == '/' && next_r == '*')
}

is_multi_line_comment_end_c_style_rune :: proc(r : rune,next_r : rune)-> bool{
    return (r == '*' && next_r == '/')
}


is_single_line_comment_c_style_token :: proc(r : Token,next_r : Token) -> bool{
    return (r.type == .BackwardSlash && next_r.type == .BackwardSlash)
}

is_single_line_comment_lisp_style_token :: proc(r : Token) -> bool{
    return (r.type == .SemiColon)
}

is_multi_line_comment_start_c_style_token :: proc(r : Token,next_r : Token)-> bool{
    return (r.type == .BackwardSlash && next_r.type == .Asterisk)
}

is_multi_line_comment_end_c_style_token :: proc(r : Token,next_r : Token)-> bool{
    return (r.type == .Asterisk && next_r.type == .BackwardSlash)
}

is_single_line_comment_c_style :: proc{is_single_line_comment_c_style_rune,is_single_line_comment_c_style_token}
is_single_line_comment_lisp_style :: proc{is_single_line_comment_lisp_style_rune,is_single_line_comment_lisp_style_token}


is_comment_start :: proc(token : Token,other : Token) -> bool{
    return (token.type == .ForwardSlash && other.type == .Asterisk);
}

is_comment_end :: proc(token : Token,other : Token) -> bool{
    return (token.type == .Asterisk && other.type == .ForwardSlash);
}

eat_all_whitespace :: proc(tokenizer : ^Tokenizer, is_included_end_of_line_chars : bool){
	if is_included_end_of_line_chars{
		r := tokenizer.at
		for is_whitespace(r){
			r = advance_by_current(tokenizer)
		}
	}else{
		temp_offset := tokenizer.offset
		r := tokenizer.at
		for is_whitespace_no_end_of_line(r){
			r = advance_by_current(tokenizer)
		}
	}
}

current_rune :: proc(tokenizer : Tokenizer) -> (rune,int){
	return utf8.decode_rune_in_string(tokenizer.src[tokenizer.offset:])
}

advance :: proc(tokenizer : ^Tokenizer,by : int){
	tokenizer.offset += by
	w : int
	tokenizer.at,w = current_rune(tokenizer^)
}

advance_by_current :: proc(tokenizer : ^Tokenizer) -> rune{
	r, w := utf8.decode_rune_in_string(tokenizer.src[tokenizer.offset:])
	tokenizer.offset += w
	next_r,next_w := current_rune(tokenizer^)
	tokenizer.at = next_r
	return tokenizer.at
}

get_token :: proc(tokenizer : ^Tokenizer) -> Token{
	using fmt
	result : Token
	eat_all_whitespace(tokenizer,true)
	r,width := current_rune(tokenizer^)
	for !is_whitespace(r){
		switch r{
			case ';':{result.type = .SemiColon;advance(tokenizer,width);return result;}
			case '(':{result.type = .OpenParen;advance(tokenizer,width);return result;}
			case ')':{result.type = .CloseParen;advance(tokenizer,width);return result;}
			case '{':{result.type = .OpenBrace;advance(tokenizer,width);return result;}
			case '}':{result.type = .CloseBrace;advance(tokenizer,width);return result;}
			case ':':{result.type = .Colon;advance(tokenizer,width);return result;}
			case ',':{result.type = .Comma;advance(tokenizer,width);return result;}
			case '.':{result.type = .Period;advance(tokenizer,width);return result;}
			case '-':{result.type = .Dash;advance(tokenizer,width);return result;}
			case '#':{result.type = .Pound;advance(tokenizer,width);return result;}
			case '<':{result.type = .LessThanSign;advance(tokenizer,width);return result;}
			case '>':{result.type = .GreaterThanSign;advance(tokenizer,width);return result;}
			case '/':{result.type = .ForwardSlash;advance(tokenizer,width);return result;}
			case '\\':{result.type = .BackwardSlash;advance(tokenizer,width);return result;}
			case '*':{result.type = .Asterisk;advance(tokenizer,width);return result;}
			//case '\0':{result.type = .Pipe;advance(tokenizer,width);return result;}
			case '"':{
				result.type = .String
				r = advance_by_current(tokenizer)
				start_offset := tokenizer.offset
				end_offset : int
				for r != '"'{
					println(r)
					r = advance_by_current(tokenizer)
				}
				result.data = tokenizer.src[start_offset:tokenizer.offset]				
				advance_by_current(tokenizer)
				return result
			}
			case :{//default
				result.type = .Identifier
				start_offset := tokenizer.offset
				r = advance_by_current(tokenizer)
				for is_alpha(r) || is_num(r) || is_allowed_in_identifier(r){
					r = advance_by_current(tokenizer)					
				}
				result.data = tokenizer.src[start_offset:tokenizer.offset]
				return result
			}
		}
	}

	return result
}
