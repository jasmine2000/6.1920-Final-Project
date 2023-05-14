int getchar();
int putchar(int c);


void makeDiamondRow(int x, char *letter) {
        char *space = " ";
        for (int i = 0; i < 10 - x; i++) {
                putchar(*space);
        }
        for (int j = 0; j < (2 * x + 1); j++) {
                putchar(*letter);
        }
        for (int i = 0; i < 10 - x; i++) {
                putchar(*space);
        }
}

void makeNDiamonds(int n, char *letter) {
        char *newline = "\n";
        for (int x = 0; x < 10; x++) {
                for (int i = 0; i < n; i++) {
                        makeDiamondRow(x, letter);
                }
                putchar(*newline);
        }
        for (int x = 8; x >= 0; x--) {
                for (int i = 0; i < n; i++) {
                        makeDiamondRow(x, letter);
                }
                putchar(*newline);
        }
}

int main() {
        makeNDiamonds(3, "j");
        return 0;
}
