%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

#define TABLE_SIZE 1000

extern int yylineno;
int curly_count = 0;

struct SymbolTable {
    char name[100];
    char type[50];
    char return_type[50];
    int  scope;
    int  frequency;
    char parameters[200];
    char array_dimensions[50];
    char pdl[20];
    int  exist;
} ST[TABLE_SIZE];

struct ConstantTable {
    char var_name[100];
    char value[100];
    char const_type[50];
    int  line_number;
    int  exist;
} CT[TABLE_SIZE];

int  searchSymbol(const char *s);
void insertOrIncrement(const char *name,const char *type);
void updateFunction(const char *name,const char *retType,const char *params,int isDef);
void updateArray(const char *name,const char *dimString);
void insertConstant(const char *var,const char *value,const char *type);

char lastIdentifier[100] = "";
int insideInitializerList = 0;  

%}


%option noyywrap

DIGIT     [0-9]
ID        [a-zA-Z_][a-zA-Z0-9_]*
TYPE      (int|float|double|char|void)
PREPROC   (\#include|\#define|\#undef|\#ifdef|\#ifndef|\#endif|\#pragma)
KEYWORD   (int|float|double|char|auto|break|case|const|continue|default|do|else|enum|extern|for|goto|if|long|register|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|volatile|while)
PREDEF_FUNC   (printf|scanf|gets|puts|strlen|strcpy|strncpy|strcat|strncat|strcmp|strncmp|malloc|calloc|free|realloc|exit|atoi|atof|atol|toupper|tolower)

%%

"#include"[ ]*"<"{ID}({ID})*".h>"   { printf("Line No. %d PREPROCESSOR DIRECTIVE - %s\n", yylineno, yytext); }
"#define"[ ]+(_|{ID})({ID})*[ ]*(.)+   { printf("Line No. %d PREPROCESSOR DIRECTIVE - %s\n", yylineno, yytext); }

"/*"([^*]|\*+[^*/])*\*+\/  { printf("Line No. %d MULTI LINE COMMENT - %s\n", yylineno, yytext); }
"//".*                     { printf("Line No. %d SINGLE LINE COMMENT - %s\n", yylineno, yytext); }
[ \t\r]+                   ;
\n                         { yylineno++; }


\"([^\\\n]|(\\.))*?\"      { insertConstant(lastIdentifier,yytext,"String Constant"); if(!insideInitializerList) lastIdentifier[0]='\0'; }
\'([^\\\n]|(\\.))*?\'      { insertConstant(lastIdentifier,yytext,"Char Constant");   if(!insideInitializerList) lastIdentifier[0]='\0'; }
{DIGIT}+"."{DIGIT}+        { insertConstant(lastIdentifier,yytext,"Float Constant");  if(!insideInitializerList) lastIdentifier[0]='\0'; }
{DIGIT}+                   { insertConstant(lastIdentifier,yytext,"Integer Constant");if(!insideInitializerList) lastIdentifier[0]='\0'; }

"{"                        { if(lastIdentifier[0] != '\0') insideInitializerList = 1; }
"}"                        { insideInitializerList = 0; if(!insideInitializerList) lastIdentifier[0]='\0'; }

{PREPROC}                  { insertOrIncrement(yytext,"PREPROCESSOR"); }
{KEYWORD}                  { insertOrIncrement(yytext,"KEYWORD"); }
{PREDEF_FUNC}              { insertOrIncrement(yytext,"FUNCTION"); }

{TYPE}[ \t]+{ID}([ \t]*\[[^]\[]*\])+[ \t]* {
    char retType[50]; sscanf(yytext,"%s",retType);
    const char *ptr = yytext;

    while(*ptr && !isspace((unsigned char)*ptr)) ptr++;
    while(*ptr && isspace((unsigned char)*ptr))  ptr++;

    char arrName[100]; int i=0;
    while(ptr[i] && ptr[i]!='[' && !isspace((unsigned char)ptr[i])) { arrName[i]=ptr[i]; i++; }
    arrName[i]='\0';

    char dimString[50]="";
    const char *p = ptr+i;
    while((p=strchr(p,'['))){
        const char *q = strchr(p,']');
        if(!q) break; 

        char buf[32];
        int bi=0;
        for(const char *r=p+1; r<q && bi<(int)sizeof(buf)-1; ++r){
            if(!isspace((unsigned char)*r)) buf[bi++]=*r; 
        }
        buf[bi]='\0';

        if(buf[0]!='\0'){ 
            if(dimString[0]=='\0') strcpy(dimString,buf);
            else { strcat(dimString,"*"); strcat(dimString,buf); }
        }
        p = q+1;
    }

    insertOrIncrement(arrName,"IDENTIFIER");
    updateArray(arrName,dimString);
    strcpy(lastIdentifier,arrName);
}

{TYPE}[ \t]+{ID}[ \t]*\((([^()]|\[[^\]\[]*\])*)\)[ \t]*\{? {
    char retType[50], funcName[100], params[200]="";
    const char *openp = strchr(yytext,'(');

    int spacePos=0;
    for(int i=0;i<(openp-yytext);i++) if(yytext[i]==' ') spacePos=i;
    strncpy(retType,yytext,spacePos);  retType[spacePos]='\0';

    int fnLen = (openp-yytext) - spacePos - 1;
    strncpy(funcName, yytext+spacePos+1, fnLen); funcName[fnLen]='\0';

    const char *ps = openp+1;
    const char *pe = strrchr(ps, ')');
    if(pe){ strncpy(params,ps,pe-ps); params[pe-ps]='\0'; }

    int isDef = (strchr(yytext,'{') != NULL);
    insertOrIncrement(funcName,"FUNCTION");
    updateFunction(funcName,retType,params,isDef);
}

{ID}   { insertOrIncrement(yytext,"IDENTIFIER"); strcpy(lastIdentifier,yytext); }

"++"|"--"|"->"|"=="|"!="|"<="|">="|"&&"|"||"|"+="|"-="|"*="|"/="|"%="|"&="|"|="|"^="|"+"|"-"|"*"|"/"|"%"|"="|"<"|">"|"!"|"&"|"|"|"^"|"~"|";"|","|"."|":"|"("|")"|"["|"]"   { printf("Line No. %d Special Character - %s\n", yylineno, yytext); }

.      { printf("Line %d: Invalid token '%s'\n",yylineno,yytext); }

%%

int searchSymbol(const char *s){
    for(int i=0;i<TABLE_SIZE;i++){
        if(ST[i].exist && strcmp(ST[i].name,s)==0) return i;
    }
    return -1;
}

void insertOrIncrement(const char *name,const char *type){
    int idx = searchSymbol(name);
    if(idx < 0){
       for(int i=0;i<TABLE_SIZE;i++){
         if(!ST[i].exist){
            ST[i].exist=1;
            strcpy(ST[i].name,name);
            strcpy(ST[i].type,type);
            ST[i].return_type[0]='\0';
            ST[i].scope=curly_count;
            ST[i].frequency=1;
            strcpy(ST[i].parameters,"-");
            strcpy(ST[i].array_dimensions,"-");
            strcpy(ST[i].pdl,"-");
            return;
         }
       }
    } else {
       ST[idx].frequency++;
    }
}

void updateFunction(const char *name,const char *retType,const char *params,int isDef){
    int idx = searchSymbol(name);
    if(idx>=0){
       strcpy(ST[idx].return_type,retType);
       strcpy(ST[idx].parameters,params);
       strcpy(ST[idx].pdl, (isDef? "DEFINED":"DECLARED"));
    }
}

void updateArray(const char *name,const char *dimString){
    int idx = searchSymbol(name);
    if(idx>=0) strcpy(ST[idx].array_dimensions,dimString);
}

void insertConstant(const char *var,const char *value,const char *type){
    for(int i=0;i<TABLE_SIZE;i++){
      if(!CT[i].exist){
         CT[i].exist=1;
         if(var && strlen(var)>0) strcpy(CT[i].var_name,var);
         else strcpy(CT[i].var_name,"-");
         strcpy(CT[i].value,value);
         strcpy(CT[i].const_type,type);
         CT[i].line_number=yylineno;
         return;
      }
    }
}

void printSymbolTable(){
    printf("\n┌────────────────────┬───────────────────────┬───────────────┬───────────┬─────────────────────────┬─────────────┬───────────┐\n");
    printf("│ %-18s │ %-21s │ %-13s │ %-9s │ %-23s │ %-11s │ %-9s │\n",
           "NAME","TYPE","RETURNTYPE","FREQUENCY","PARAMETERS","DIMENSIONS","PDL");
    printf("├────────────────────┼───────────────────────┼───────────────┼───────────┼─────────────────────────┼─────────────┼───────────┤\n");
    for(int i=0;i<TABLE_SIZE;i++){
       if(ST[i].exist){
         printf("│ %-18s │ %-21s │ %-13s │ %-9d │ %-23s │ %-11s │ %-9s │\n",
           ST[i].name, ST[i].type,
           (strlen(ST[i].return_type)?ST[i].return_type:"-"), ST[i].frequency,
           ST[i].parameters, ST[i].array_dimensions, ST[i].pdl);
       }
    }
    printf("└────────────────────┴───────────────────────┴───────────────┴───────────┴─────────────────────────┴─────────────┴───────────┘\n");
}

void printConstantTable(){
    printf("\n┌────────────────────┬────────────────────┬────────────────────────┬───────────────┐\n");
    printf("│ %-18s │ %-18s │ %-22s │ %-13s │\n","Variable Name","Value","Type","Line Number");
    printf("├────────────────────┼────────────────────┼────────────────────────┼───────────────┤\n");
    for(int i=0;i<TABLE_SIZE;i++){
     if(CT[i].exist){
       printf("│ %-18s │ %-18s │ %-22s │ %-13d │\n",
              CT[i].var_name,CT[i].value,CT[i].const_type,CT[i].line_number);
     }
    }
    printf("└────────────────────┴────────────────────┴────────────────────────┴───────────────┘\n");
}

int main(){
    yylex();
    printf("\n\nSymbol Table\n\n");
    printSymbolTable();
    printf("\n\n\nConstant Table\n");
    printConstantTable();
    return 0;
}

