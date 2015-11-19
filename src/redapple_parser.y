%{
#include "Model/nodes.h"
#include <list>
using namespace std;

#define YYERROR_VERBOSE 1

Node *programBlock; /* the top level root node of our final AST */

extern int yylex();
extern int yylineno;
extern char* yytext;
extern int yyleng;

void yyerror(const char *s);

%}

 

/* Represents the many different ways we can access our data */

%union {
    Node *nodes;
    char *str;
    int token;
}

 

/* Define our terminal symbols (tokens). This should

   match our tokens.l lex file. We also define the node type

   they represent.

 */

%token <str> ID INTEGER DOUBLE
%token <token> CEQ CNE CGE CLE MBK
%token <token> '<' '>' '=' '+' '-' '*' '/' '%' '^' '&' '|' '~' '@' '?' ':'
%token <token> PP SS LF RF AND OR '!' NSP PE SE ME DE AE OE XE MODE FLE FRE
%token <str> STRING CHAR
%token <token> IF ELSE WHILE DO UNTIL GOTO FOR FOREACH 
%token <token> DELEGATE DEF DEFINE IMPORT USING NAMESPACE DEFMACRO
%token <token> RETURN NEW THIS 
%token <str> KWS_EXIT KWS_ERROR KWS_TSZ KWS_STRUCT KWS_FWKZ KWS_FUNC_XS KWS_TYPE

/* 
   Define the type of node our nonterminal symbols represent.
   The types refer to the %union declaration above. Ex: when
   we call an ident (defined by union type ident) we are really
   calling an (NIdentifier*). It makes the compiler happy.
 */

%type <nodes> program
%type <nodes> def_module_statement
%type <nodes> def_module_statements
%type <nodes> def_statement
%type <nodes> def_statements
%type <nodes> for_state
%type <nodes> if_state
%type <nodes> while_state
%type <nodes> dowhile_state
%type <nodes> dountil_state
%type <nodes> statement
%type <nodes> statements
%type <nodes> block
%type <nodes> var_def
%type <nodes> marco_def
%type <nodes> macro_def_args
%type <nodes> macro_call
%type <nodes> func_def
%type <nodes> func_def_args
%type <nodes> func_def_xs 
%type <nodes> numeric
%type <nodes> expr
%type <nodes> call_arg 
%type <nodes> call_args 
%type <nodes> return_state

//%type <token> operator 这个设计容易引起规约冲突，舍弃
/* Operator precedence for mathematical operators */


%left '~'
%left '&' '|'
%left CEQ CNE CLE CGE '<' '>' '='
%left '+' '-'
%left '*' '/' '%' '^'
%left '.'
%left MBK '@'

%start program

%%

program : def_statements { programBlock = Node::getList($1); }
        ;

def_module_statement : KWS_STRUCT ID '{' def_statements '}' { $$ = Node::make_list(3, IDNode::Create($1), IDNode::Create($2), $4); }
                     | KWS_STRUCT ID ';' { $$ = Node::make_list(3, IDNode::Create($1), IDNode::Create($2), Node::Create()); }
                     ;

def_module_statements  : def_module_statement { $$ = Node::getList($1); }
                       | def_module_statements def_module_statement { $$ = $1; $$->addBrother(Node::getList($2)); }
                       ;

func_def_xs : KWS_FUNC_XS { $$ = IDNode::Create($1); }
            | func_def_xs KWS_FUNC_XS {$$ = $1; $$->addBrother(IDNode::Create($2)); }
            ;

def_statement : var_def ';' { $$ = $1; }
              | func_def 
              | marco_def
              | macro_call
              | def_module_statement 
              | func_def_xs func_def { $$ = $2; $2->addBrother(Node::getList($1)); } 
              | IMPORT STRING { $$ = Node::make_list(2, IDNode::Create("import"), IDNode::Create($2) ); }
              ;

def_statements : def_statement { $$ = Node::getList($1); }
               | def_statements def_statement { $$ = $1; $$->addBrother(Node::getList($2)); }
               ;

statements : statement { $$ = Node::getList($1); }
           | statements statement { $$ = $1; $$->addBrother(Node::getList($2)); }
           ;

statement : def_statement 
          | expr ';' { $$ = $1; } 
          | block 
          | if_state
          | while_state
          | dowhile_state
          | dountil_state
          | for_state
          | return_state
          ;

if_state : IF '(' expr ')' statement { $$ = Node::make_list(3, IDNode::Create("if"), $3, $5); }
         | IF '(' expr ')' statement ELSE statement { $$ = Node::make_list(4, IDNode::Create("if"), $3, $5, $7); }
         ;

while_state : WHILE '(' expr ')' statement { $$ = Node::make_list(3, IDNode::Create("while"), $3, $5); }
            ;

dowhile_state : DO statement WHILE '(' expr ')' ';' { $$ = Node::make_list(3, IDNode::Create("dowhile"), $2, $5); }
              ;
dountil_state : DO statement UNTIL '(' expr ')' ';' { $$ = Node::make_list(3, IDNode::Create("dountil"), $2, $5); }
              ;

for_state : FOR '(' expr ';' expr ';' expr ')' statement { $$ = Node::make_list(5, IDNode::Create("for"), $3, $5, $7, $9); }
          | FOR '(' var_def ';' expr ';' expr ')' statement { $$ = Node::make_list(5, IDNode::Create("for"), Node::Create($3), $5, $7, $9); }
          ;

return_state : RETURN ';' { $$ = IDNode::Create("return"); }
             | RETURN expr ';' { $$ = IDNode::Create("return"); $$->addBrother($2); }              

block : '{' statements '}' { $$ = Node::Create($2); }
      | '{' '}' { $$ = Node::Create(); }
      ; 

var_def : KWS_TYPE ID { $$ = Node::make_list(3, IDNode::Create("set"), IDNode::Create($1), IDNode::Create($2)); }
        | ID ID { $$ = Node::make_list(3, IDNode::Create("set"), IDNode::Create($1), IDNode::Create($2)); }
        | KWS_TYPE ID '=' expr { $$ = Node::make_list(4, IDNode::Create("set"), IDNode::Create($1), IDNode::Create($2), $4); }
        | ID ID '=' expr { $$ = Node::make_list(4, IDNode::Create("set"), IDNode::Create($1), IDNode::Create($2), $4); }
        ;

macro_def_args : ID { $$ = IDNode::Create($1); }
               | macro_def_args ',' ID { $$ = $1; $1->addBrother(IDNode::Create($3)); }
               ;

marco_def : DEFMACRO ID '(' macro_def_args ')' block
            { $$ = Node::make_list(4, IDNode::Create("defmacro"), IDNode::Create($2), $4, $6); }
          ;

macro_call : '@' ID { $$ = IDNode::Create($2); }
           | macro_call '(' call_args ')' { $$ = $1; $$->addBrother($3); }
           | macro_call block { $$ = $1; $$->addBrother(Node::getList($2)); }
           | macro_call ID block { $$ = $1; $$->addBrother(IDNode::Create($2)); $$->addBrother(Node::getList($3)); }
           ;

func_def : ID ID '(' func_def_args ')' block
            { $$ = Node::make_list(5, IDNode::Create("function"), IDNode::Create($1), IDNode::Create($2), $4, $6); }
         | KWS_TYPE ID '(' func_def_args ')' block
            { $$ = Node::make_list(5, IDNode::Create("function"), IDNode::Create($1), IDNode::Create($2), $4, $6); }
         | ID ID '(' func_def_args ')' ';'
            { $$ = Node::make_list(5, IDNode::Create("function"), IDNode::Create($1), IDNode::Create($2), $4); }
         | KWS_TYPE ID '(' func_def_args ')' ';'
            { $$ = Node::make_list(5, IDNode::Create("function"), IDNode::Create($1), IDNode::Create($2), $4); }
         ;

func_def_args : var_def { $$ = Node::Create(Node::Create($1)); }
              | func_def_args ',' var_def { $$ = $1; $$->addChildren(Node::Create($3)); }
              | %empty  { $$ = Node::Create(); }
              ;

numeric : INTEGER { $$ = IntNode::Create($1); }
        | DOUBLE { $$ = FloatNode::Create($1); }
        ;

expr : expr '=' expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("="), $1, $3); }
     | ID '(' call_args ')' { $$ = Node::make_list(2, IDNode::Create("call"), IDNode::Create($1)); $$->addBrother($3); }
     | ID { $$ = IDNode::Create($1); }
     | numeric 
     | macro_call
     | STRING { $$ = StringNode::Create($1); }
     | KWS_TSZ 
     | NEW ID '(' call_args ')' { $$ = Node::make_list(3, IDNode::Create("new"), IDNode::Create($2), $4); }
     | expr CEQ expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("=="), $1, $3); }
     | expr CNE expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("!="), $1, $3); }
     | expr CLE expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("<="), $1, $3); }
     | expr CGE expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create(">="), $1, $3); }
     | expr '<' expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("<"), $1, $3); }
     | expr '>' expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create(">"), $1, $3); }
     | expr '+' expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("+"), $1, $3); }
     | expr '-' expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("-"), $1, $3); }
     | expr '*' expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("*"), $1, $3); }
     | expr '/' expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("/"), $1, $3); }
     | expr '%' expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("%"), $1, $3); }
     | expr '^' expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("^"), $1, $3); }
     | expr '&' expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("&"), $1, $3); }
     | expr '|' expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("|"), $1, $3); }
     | expr '.' expr { $$ = Node::make_list(4, IDNode::Create("opt2"), IDNode::Create("."), $1, $3); }
     | '~' expr { $$ = Node::make_list(4, IDNode::Create("opt1"), IDNode::Create("~"), $2); }
     | '(' expr ')'  /* ( expr ) */  { $$ = $2; }
     ;


call_arg  :  expr { $$ = $1;  }
          |  ID '=' expr { $$ = Node::make_list(3, IDNode::Create("="), $1, $3); }
          ;

call_args : %empty { $$ = Node::Create(); }
          | call_arg { $$ = Node::getList($1); }
          | call_args ',' call_arg  { $$ = $1; $$->addBrother(Node::getList($3)); }
          ;

%%

void yyerror(const char* s){
    fprintf(stderr, "%s \n", s);    
    fprintf(stderr, "line %d: ", yylineno);
    fprintf(stderr, "text %s \n", yytext);
    exit(1);
}