/* Example 1 */

int fn();

int forward_null_example1(int *p) {
    int x;
    if( p == 0 ) {
        x = 0;
    } else {
        x = *p;
    }
    x += fn();
    *p = x;   // ERROR: p is potentially NULL
    return 0;
}

/* Example 2 */

struct S {
    int x;
};

void fn2(struct S *s) {
    s->x = 0;
}

void forward_null_example2(struct S *s) {
    if (!s) {
        // print an error
    }

    fn2(s);
}
