int putchar(int c);

unsigned long findFib(int n) {
        unsigned long buffer[n];
        buffer[0] = 1;
        buffer[1] = 1;
        for (int i = 2; i < n; i++) {
            buffer[i] = buffer[i - 1] + buffer[i - 2];
        }

        return buffer[n - 1];
}

int main() {        
        unsigned long x = findFib(92);

        int number[100];
        for (int i = 0; i < 100; i++) {
            number[i] = x & 1;
            x = x >> 1;
        }

        int numStarted = 0;
        for (int i = 99; i >= 0; i--) {
            if (!numStarted && number[i]) {
                numStarted = 1;
            }
            if (numStarted) {
                putchar('0' + number[i]);
            }
        }
        
        return 0;
}
