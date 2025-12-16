%{
/* Test grammar file for collie-lsp */
#include <stdio.h>
%}

%token NUMBER
%token IDENTIFIER
%token PLUS MINUS
%token TIMES DIVIDE

%left PLUS MINUS
%left TIMES DIVIDE

%%

program
    : expression
    ;

expression
    : expression PLUS term
    | expression MINUS term
    | term
    ;

term
    : term TIMES factor
    | term DIVIDE factor
    | factor
    ;

factor
    : NUMBER
    | IDENTIFIER
    | '(' expression ')'
    ;

%%

int main() {
    return 0;
}
