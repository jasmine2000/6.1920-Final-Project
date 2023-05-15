int putchar(int c);

char* space = " ";
char* letter = "x";
char* newline = "\n";

int width = 5;

void printSpace() {
    putchar(*space);
    putchar(*space);
}

void printNum(char* symbol, int num) {
    for (int i = 0; i < num; i++) {
        putchar(*symbol);
    }
}

void printB(int i) {
    if (i > 8) {
        printNum(space, width);
        return;
    }

    putchar(*letter);
    switch(i) {
        case 5:
        case 6:
        case 7:
            printNum(space, 3);
            break;
        case 4:
        case 8:
            printNum(letter, 3);
            break;
        default:
            printNum(space, 4);
            return;
    }
    putchar(*letter);
}

void printL(int i) {
    if (i > 8) {
        putchar(*space);
        return;
    }
    putchar(*letter);
}

void printU(int i) {
    if (i > 8) {
        printNum(space, width);
        return;
    }

    if (i < 4) {
        printNum(space, 5);
        return;
    }

    putchar(*letter);
    switch(i) {
        case 4:
        case 5:
        case 6:
        case 7:
            printNum(space, 3);
            break;
        case 8:
            printNum(letter, 3);
            break;
    }
    putchar(*letter);
}

void printE(int i) {
    if (i > 8) {
        printNum(space, width);
        return;
    }

    if (i < 4) {
        printNum(space, 5);
        return;
    }

    putchar(*letter);
    switch(i) {
        case 5:
            printNum(space, 3);
            putchar(*letter);
            break;
        case 7:
            printNum(space, 4);
            break;
        case 4:
        case 6:
        case 8:
            printNum(letter, 4);
            break;
    }
}

void printS(int i) {
    if (i > 8) {
        printNum(space, width);
        return;
    }

    if (i < 4) {
        printNum(space, 5);
        return;
    }

    switch(i) {
        case 5:
            putchar(*letter);
            printNum(space, 4);
            break;
        case 7:
            printNum(space, 4);
            putchar(*letter);
            break;
        case 4:
        case 6:
        case 8:
            printNum(letter, 5);
            break;
    }
}

void printP(int i) {
    if (i < 4) {
        printNum(space, width);
        return;
    }

    putchar(*letter);
    switch(i) {
        case 5:
        case 6:
        case 7:
            printNum(space, 3);
            putchar(*letter);
            break;
        case 4:
        case 8:
            printNum(letter, 4);
            break;
    }
}

void printC(int i) {
    if (i > 8) {
        printNum(space, width);
        return;
    }

    if (i < 4) {
        printNum(space, 5);
        return;
    }

    putchar(*letter);
    switch(i) {
        case 4:
        case 8:
            printNum(letter, 4);
            break;
        default:
            printNum(space, 4);
    }
}

int main() {        
        for (int i = 0; i < 13; i++) {
            printB(i);
            printSpace();

            printL(i);
            printSpace();

            printU(i);
            printSpace();

            printE(i);
            printSpace();

            printS(i);
            printSpace();

            printP(i);
            printSpace();

            printE(i);
            printSpace();

            printC(i);
            printSpace();

            putchar(*newline);
        }
        
        return 0;
}
