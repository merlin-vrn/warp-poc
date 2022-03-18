#if !defined(_ANSI_H)
#define _ANSI_H

#define ANSI_RESET "\033[0m"

#define ANSI_BLACK "0"
#define ANSI_RED "1"
#define ANSI_GREEN "2"
#define ANSI_YELLOW "3"
#define ANSI_BLUE "4"
#define ANSI_MAGENTA "5"
#define ANSI_CYAN "6"
#define ANSI_WHITE "7"

#define ANSI_BRIGHT(n) n ";1"

#define ANSI_FG(n) "\033[3" n "m"
#define ANSI_FG_DEFAULT "\033[39m\033[22m"
#define ANSI_BG(n) "\033[4" n "m"
#define ANSI_BG_DEFAULT "\033[49m"

// Usage: ANSI_FG(ANSI_RED) "text will be red" ANSI_RESET
//        ANSI_FG(ANSI_BRIGHT(ANSI_BLUE)) ANSI_BG(ANSI_YELLOW) "text will be light blue on yellow (brown) bg" ANSI_RESET
#endif
