struct vp_settings {
    size_t prec_limit;
    unsigned short rounding_mode;
};

static VALUE
restore_vp_settings(VALUE saved_ptr)
{
    struct vp_settings *saved = (struct vp_settings *)saved_ptr;
    VpSetPrecLimit(saved->prec_limit);
    VpSetRoundMode(saved->rounding_mode);
    return Qnil;
}

// Calculate the inverse of x using the Newton-Raphson method.
// Assumes no precision limit and ROUND_HALF_UP. See VpDivdNewton.
static VALUE
newton_raphson_inverse(VALUE x, size_t prec) {
    BDVALUE bdone = NewZeroWrap(1, 1);
    VpSetOne(bdone.real);
    VALUE one = bdone.bigdecimal;

    // Initial approximation: 10^18 / (leading 9 digits of x), calculated in 64-bit integer.
    // Truncating x to 9 digits and the quotient to an integer keep the relative error below 1.2e-8,
    // so it has at least 7 correct digits.
    const size_t initial_digits = 7;
    const DECDIG_DBL base_sq = (DECDIG_DBL)BIGDECIMAL_BASE * BIGDECIMAL_BASE;
    BDVALUE bdx = GetBDValueMust(x);
    DECDIG_DBL x_lead = (DECDIG_DBL)bdx.real->frac[0] * BIGDECIMAL_BASE + (bdx.real->Prec >= 2 ? bdx.real->frac[1] : 0);
    int shift = 0;
    while (x_lead < base_sq / 10) {
        x_lead *= 10;
        shift++;
    }
    // Dividing base_sq - 1 instead of base_sq keeps the quotient below 10 * BASE,
    // so that frac[0] of inv0 never reaches BASE.
    DECDIG_DBL inv_lead = (base_sq - 1) / (x_lead / BIGDECIMAL_BASE);
    for (int i = 0; i < shift; i++) inv_lead *= 10;
    BDVALUE inv0 = NewZeroWrap(1, 2 * BIGDECIMAL_COMPONENT_FIGURES);
    VpSetOne(inv0.real);
    inv0.real->frac[0] = (DECDIG)(inv_lead / BIGDECIMAL_BASE);
    inv0.real->frac[1] = (DECDIG)(inv_lead % BIGDECIMAL_BASE);
    inv0.real->Prec = 2;
    inv0.real->exponent = 1 - bdx.real->exponent;
    VpNmlz(inv0.real);
    RB_GC_GUARD(bdx.bigdecimal);
    VALUE inv = inv0.bigdecimal;

    int bl = 1;
    while (((size_t)1 << bl) < prec) bl++;

    // Each iteration doubles the number of correct digits, and the rounding error of
    // the previous iteration is squared into the new digits. Margin digits keep the
    // squared error below the last digit, otherwise it can grow over iterations.
    const size_t margin = 4;
    for (int i = bl; i >= 0; i--) {
        size_t n = (prec >> i) + margin;
        if (n > prec) n = prec;
        // inv0 already has this precision. The last iteration is kept to round inv to prec digits.
        if (n <= initial_digits && i > 0) continue;
        // Newton-Raphson iteration: inv_next = inv + inv * (1 - x * inv)
        // (1 - x * inv) is about 10^(-n/2), so calculating it in n/2 digits is enough for inv_next in n digits.
        VALUE one_minus_x_inv = BigDecimal_sub2(
            one,
            BigDecimal_mult(BigDecimal_mult2(x, one, SIZET2NUM(n + 1)), inv),
            SIZET2NUM(n / 2 + margin)
        );
        inv = BigDecimal_add2(
            inv,
            BigDecimal_mult(inv, one_minus_x_inv),
            SIZET2NUM(n)
        );
    }
    return inv;
}

// Calculates divmod by multiplying approximate reciprocal of y
static void
divmod_by_inv_mul(VALUE x, VALUE y, VALUE inv, VALUE *res_div, VALUE *res_mod) {
    VALUE div = BigDecimal_fix(BigDecimal_mult(x, inv));
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
    ssize_t start = src->exponent - (ssize_t)rshift - (ssize_t)length;
    ssize_t from = Max(start, 0);
    ssize_t to = Min(start + (ssize_t)length, (ssize_t)src->Prec);
    if (from >= to) return;
    memcpy(dest + (from - start), src->frac + from, (size_t)(to - from) * sizeof(DECDIG));
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
 * Reciprocal of y needs block_digits + 1 precision.
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
    VALUE yinv = newton_raphson_inverse(y, block_digits + 1);

    BDVALUE divident = NewZeroWrap(1, BIGDECIMAL_COMPONENT_FIGURES * (y_figs + block_figs));
    BDVALUE div_result = NewZeroWrap(1, BIGDECIMAL_COMPONENT_FIGURES * (num_blocks * block_figs + 1));
    BDVALUE bdx = GetBDValueMust(x);

    VALUE mod = BigDecimal_fix(BigDecimal_decimal_shift(x, SSIZET2NUM(-(ssize_t)(num_blocks * block_digits))));
    for (ssize_t i = (ssize_t)(num_blocks - 1); i >= 0; i--) {
        memset(divident.real->frac, 0, (y_figs + block_figs) * sizeof(DECDIG));

        BDVALUE bdmod = GetBDValueMust(mod);
        slice_copy(divident.real->frac, bdmod.real, 0, y_figs);
        slice_copy(divident.real->frac + y_figs, bdx.real, (size_t)i * block_figs, block_figs);
        RB_GC_GUARD(bdmod.bigdecimal);

        VpSetSign(divident.real, 1);
        divident.real->exponent = (ssize_t)(y_figs + block_figs);
        divident.real->Prec = y_figs + block_figs;
        VpNmlz(divident.real);

        VALUE div;
        divmod_by_inv_mul(divident.bigdecimal, y, yinv, &div, &mod);
        BDVALUE bddiv = GetBDValueMust(div);
        slice_copy(div_result.real->frac + (num_blocks - (size_t)i - 1) * block_figs, bddiv.real, 0, block_figs + 1);
        RB_GC_GUARD(bddiv.bigdecimal);
    }
    VpSetSign(div_result.real, 1);
    div_result.real->exponent = (ssize_t)(num_blocks * block_figs + 1);
    div_result.real->Prec = num_blocks * block_figs + 1;
    VpNmlz(div_result.real);
    RB_GC_GUARD(bdx.bigdecimal);
    RB_GC_GUARD(divident.bigdecimal);
    RB_GC_GUARD(div_result.bigdecimal);
    *div_out = div_result.bigdecimal;
    *mod_out = mod;
}

struct vp_divd_newton_args {
    Real *c, *r, *a, *b;
};

static VALUE
VpDivdNewtonInner(VALUE args_ptr)
{
    struct vp_divd_newton_args *args = (struct vp_divd_newton_args *)args_ptr;
    Real *c = args->c, *r = args->r, *a = args->a, *b = args->b;
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
    a2.real->exponent = (ssize_t)(base_prec + div_prec);
    b2.real->exponent = (ssize_t)base_prec;

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
    if (!VpIsZero(c)) AddExponent(c, a->exponent - b->exponent - (ssize_t)div_prec);
    if (!VpIsZero(r)) AddExponent(r, a->exponent - (ssize_t)(base_prec + div_prec));
    RB_GC_GUARD(a2.bigdecimal);
    RB_GC_GUARD(b2.bigdecimal);
    RB_GC_GUARD(c2.bigdecimal);
    RB_GC_GUARD(r2.bigdecimal);
    return Qnil;
}

// Newton-Raphson iteration converges from below, so a rounding mode that rounds toward zero
// (ROUND_DOWN, ROUND_FLOOR) adds error in the same direction at every iteration.
// Calculate with ROUND_HALF_UP and without precision limit, and restore them even if an exception is raised.
static void
VpDivdNewton(Real *c, Real *r, Real *a, Real *b)
{
    struct vp_divd_newton_args args = {c, r, a, b};
    struct vp_settings saved = {VpGetPrecLimit(), VpGetRoundMode()};
    VpSetPrecLimit(0);
    VpSetRoundMode(VP_ROUND_HALF_UP);
    rb_ensure(VpDivdNewtonInner, (VALUE)&args, restore_vp_settings, (VALUE)&saved);
}
