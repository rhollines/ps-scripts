struct buf_t {
    int x;
};

struct buf_t some_function();

int basic_reverse_null(struct buf_t *request_buf) {
    *request_buf = some_function();     // dereferencing request_buf in assignment

    if (request_buf == 0)           // NULL check AFTER deref
        return -1;

    return 0;
}
