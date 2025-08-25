static VALUE
bd_one_lshift(ssize_t n) {
    BDVALUE x = NewZeroWrap(1, BIGDECIMAL_COMPONENT_FIGURES);
    x.real->exponent = n / BIGDECIMAL_COMPONENT_FIGURES;
    int mod = n % BIGDECIMAL_COMPONENT_FIGURES;
    if (mod < 0) mod += BIGDECIMAL_COMPONENT_FIGURES;
    x.real->exponent = (n - mod) / BIGDECIMAL_COMPONENT_FIGURES + 1;
    VpSetSign(x.real, 1);
    DECDIG v = 1;
    for (int i = 0; i < mod; i++) v = v * 10;
    x.real->frac[0] = v;
    return x.bigdecimal;
}

static VALUE
bd_lshift_as_int(VALUE x, ssize_t n) {
    if (n == 0) return x;
    VALUE y = BigDecimal_mult(x, bd_one_lshift(n));
    return n > 0 ? y : BigDecimal_fix(y);
}

static VALUE
bd_rshift_as_int(VALUE x, ssize_t n) {
    return bd_lshift_as_int(x, -n);
}

// Calculate the inverse of x using the Newton-Raphson method.
// Returns approximate value of 10**(size + x.exponent).div(x)
static VALUE
newton_raphson_inverse(VALUE x, size_t size) {
    size_t x_size = NUM2SIZET(BigDecimal_exponent(x));
    size_t n = 2;

    // Initial approximation in n digits
    BDVALUE y0 = NewZeroWrap(1, BIGDECIMAL_COMPONENT_FIGURES);
    VpSetOne(y0.real);
    y0.real->frac[0] = NUM2INT(BigDecimal_to_i(bd_one_lshift(2 * n))) / NUM2INT(BigDecimal_to_i(bd_rshift_as_int(x, x_size - n)));
    VALUE y = y0.bigdecimal;

    int bl = 1;
    while (((size_t)1 << bl) < size) bl++;
    for (int i = bl; i >= 0; i--) {
        /*
         * Reciprocal of x can be calculated with Newton's method
         * by repeating InvX_next = InvX * (2 - x * InvX)
         * where InvX is the current approximation of 1/x in n digits
         *   InvX = y.quo(10**(n + x.exponent)) + error
         * and InvX_next is the next approximation of 1/x in n2 digits
         *   InvX_next = y_next.quo(10**(n2 + x.exponent)) + error
         */
        size_t n2 = (size >> i) + 2;
        if (n2 > size) n2 = size;
        size_t x_shift = (x_size > n2 ? x_size - n2 : 0) - 2;
        y = bd_rshift_as_int(
            BigDecimal_add(
                bd_lshift_as_int(y, x_size + n - x_shift),
                BigDecimal_mult(
                    BigDecimal_sub(
                        bd_one_lshift(x_size + n - x_shift),
                        BigDecimal_mult(bd_rshift_as_int(x, x_shift), y)
                    ),
                    y
                )
            ),
            x_size + 2 * n - n2 - x_shift
        );
        n = n2;
    }
    return y;
}

// Calculates divmod by multiplying approximate reciprocal of y
static void
divmod_by_inv_mul(VALUE x, VALUE y, VALUE inv, size_t inv_digits, VALUE *res_div, VALUE *res_mod) {
    VALUE div = bd_rshift_as_int(BigDecimal_mult(bd_rshift_as_int(x, NUM2SSIZET(BigDecimal_exponent(y))), inv), inv_digits);
    VALUE mod = BigDecimal_sub(x, BigDecimal_mult(div, y));
    while (RTEST(BigDecimal_lt(mod, INT2FIX(0)))) {
        mod = BigDecimal_add(mod, y);
        div = BigDecimal_sub(div, INT2FIX(1));
    }
    while (RTEST(BigDecimal_ge(mod, y))) {
        mod = BigDecimal_sub(mod, y);
        div = BigDecimal_add(div, INT2FIX(1));
    }
    *res_div = div;
    *res_mod = mod;
}

static void
slice_copy(DECDIG *dest, Real *src, size_t rshift, size_t length) {
    ssize_t start = src->exponent - rshift - length;
    if (start >= (ssize_t)src->Prec) return;
    if (start < 0) {
        dest -= start;
        length += start;
        start = 0;
    }
    size_t max_length = src->Prec - start;
    memcpy(dest, src->frac + start, Min(length, max_length) * sizeof(DECDIG));
}

/* Calculates divmod using Newton-Raphson method.
 * x and y must be a BigDecimal representing an integer value.
 *
 * To calculate with low cost, we need to split x into blocks and perform divmod for each block.
 * x_digits = remaining_digits(<= y_digits) + block_digits * num_blocks
 *
 * Example:
 * xxx_xxxxx_xxxxx_xxxxx(18 digits) / yyyyy(5 digits)
 * remaining_digits = 3, block_digits = 5, num_blocks = 3
 * repeating xxxxx_xxxxxx.divmod(yyyyy) calculation 3 times.
 *
 * In each divmod step, dividend is at most (y_digits + block_digits) digits and divisor is y_digits digits.
 * Reciprocal of y needs block_digits precision.
 */
static void
divmod_newton(VALUE x, VALUE y, VALUE *div_out, VALUE *mod_out) {
    size_t x_digits = NUM2SIZET(BigDecimal_exponent(x));
    size_t y_digits = NUM2SIZET(BigDecimal_exponent(y));
    if (x_digits <= y_digits) x_digits = y_digits + 1;

    size_t n = x_digits / y_digits;
    size_t block_figs = (x_digits - y_digits) / n / BIGDECIMAL_COMPONENT_FIGURES + 1;
    size_t block_digits = block_figs * BIGDECIMAL_COMPONENT_FIGURES;
    size_t num_blocks = (x_digits - y_digits + block_digits - 1) / block_digits;
    size_t y_figs = (y_digits - 1) / BIGDECIMAL_COMPONENT_FIGURES + 1;
    VALUE yinv = newton_raphson_inverse(y, block_digits);

    BDVALUE divident = NewZeroWrap(1, BIGDECIMAL_COMPONENT_FIGURES * (y_figs + block_figs));
    BDVALUE div_result = NewZeroWrap(1, BIGDECIMAL_COMPONENT_FIGURES * (num_blocks * block_figs + 1));
    BDVALUE bdx = GetBDValueMust(x);

    VALUE mod = bd_rshift_as_int(x, num_blocks * block_digits);

    for (ssize_t i = num_blocks - 1; i >= 0; i--) {
        memset(divident.real->frac, 0, (y_figs + block_figs) * sizeof(DECDIG));

        BDVALUE bdmod = GetBDValueMust(mod);
        slice_copy(divident.real->frac, bdmod.real, 0, y_figs);
        slice_copy(divident.real->frac + y_figs, bdx.real, i * block_figs, block_figs);
        RB_GC_GUARD(bdmod.bigdecimal);

        VpSetSign(divident.real, 1);
        divident.real->exponent = y_figs + block_figs;
        divident.real->Prec = y_figs + block_figs;
        VpNmlz(divident.real);

        VALUE div;
        divmod_by_inv_mul(divident.bigdecimal, y, yinv, block_digits, &div, &mod);
        BDVALUE bddiv = GetBDValueMust(div);
        slice_copy(div_result.real->frac + (num_blocks - i - 1) * block_figs, bddiv.real, 0, block_figs + 1);
        RB_GC_GUARD(bddiv.bigdecimal);
    }
    VpSetSign(div_result.real, 1);
    div_result.real->exponent = num_blocks * block_figs + 1;
    div_result.real->Prec = num_blocks * block_figs + 1;
    VpNmlz(div_result.real);
    RB_GC_GUARD(bdx.bigdecimal);
    RB_GC_GUARD(divident.bigdecimal);
    RB_GC_GUARD(div_result.bigdecimal);
    *div_out = div_result.bigdecimal;
    *mod_out = mod;
}

static VALUE
VpDivdNewtonInner(VALUE args_ptr)
{
    Real **args = (Real**)args_ptr;
    Real *c = args[0], *r = args[1], *a = args[2], *b = args[3];
    BDVALUE a2, b2, c2, r2;
    VALUE div, mod, a2_frac = Qnil;
    size_t div_prec = c->MaxPrec - 1;
    size_t base_prec = b->Prec;

    a2 = NewZeroWrap(1, a->Prec * BIGDECIMAL_COMPONENT_FIGURES);
    b2 = NewZeroWrap(1, b->Prec * BIGDECIMAL_COMPONENT_FIGURES);
    VpAsgn(a2.real, a, 1);
    VpAsgn(b2.real, b, 1);
    VpSetSign(a2.real, 1);
    VpSetSign(b2.real, 1);
    a2.real->exponent = base_prec + div_prec;
    b2.real->exponent = base_prec;

    if ((ssize_t)a2.real->Prec > a2.real->exponent) {
        a2_frac = BigDecimal_frac(a2.bigdecimal);
        VpMidRound(a2.real, VP_ROUND_DOWN, 0);
    }
    divmod_newton(a2.bigdecimal, b2.bigdecimal, &div, &mod);
    if (a2_frac != Qnil) mod = BigDecimal_add(mod, a2_frac);

    c2 = GetBDValueMust(div);
    r2 = GetBDValueMust(mod);
    VpAsgn(c, c2.real, VpGetSign(a) * VpGetSign(b));
    VpAsgn(r, r2.real, VpGetSign(a));
    AddExponent(c, a->exponent);
    AddExponent(c, -b->exponent);
    AddExponent(c, -div_prec);
    AddExponent(r, a->exponent);
    AddExponent(r, -base_prec - div_prec);
    RB_GC_GUARD(a2.bigdecimal);
    RB_GC_GUARD(a2.bigdecimal);
    RB_GC_GUARD(c2.bigdecimal);
    RB_GC_GUARD(r2.bigdecimal);
    return Qnil;
}

static VALUE
ensure_restore_prec_limit(VALUE limit)
{
    VpSetPrecLimit(NUM2SIZET(limit));
    return Qnil;
}

static void
VpDivdNewton(Real *c, Real *r, Real *a, Real *b)
{
    Real *args[4] = {c, r, a, b};
    size_t pl = VpGetPrecLimit();
    VpSetPrecLimit(0);
    // Ensure restoring prec limit because some methods used in VpDivdNewtonInner may raise an exception
    rb_ensure(VpDivdNewtonInner, (VALUE)args, ensure_restore_prec_limit, SIZET2NUM(pl));
}
