# Second client of the value-domain accelerator layer (gamma_multipoint.rb):
# Gamma via the incomplete gamma series
#   gamma(a) =~ gamma_lower(a, r) = r**a * e**-r * (1/a) * S,
#   S = 1 + sum_{j>=1} prod_{i=1..j} r / (a + i),   r =~ prec * ln(10)
# for full-digit a in [0.5, 3]. The term ratio has a CONSTANT numerator, so the
# 2x2 matrix tables degenerate: M_s = r**s is an exact scalar and only two value
# tables (D, N) of degree s are needed - the doubling is ~3x lighter per term
# than the gamma client's (degree-3 den, three tables).
#
# Usage: ruby -Ilib -Itmp/arm64-darwin24/stage/lib incgamma_mp_check.rb [acc|loss|bench]
require 'bigdecimal'
require 'bigdecimal/math'
require 'bigdecimal/math/gamma'
require 'benchmark'

BigMath.gamma(BigDecimal('1.5'), 20)
MP = BigMath.const_get(:Gamma)::Multipoint
G = BigMath.const_get(:Gamma)
abort 'requires GMP-backed Integer' unless MP.enabled

$incg_guard_scale = 1 # measured loss is 0.26-0.50 * S * bl; scale 1 keeps a ~2x margin. loss mode sets 0

# Value tables [D, N] of P_s(z) = prod_{t=z+1..z+s} [[a+t, 0], [r, r]]
# at z = u * cap_s (u = 0..cap_s); M_s = r**s is exact and returned separately.
def incg_value_tables(xa, s2, r, cap_s, keep)
  dtab = MP.fp_normalize([xa + s2, xa + 2 * s2], -keep, keep)
  # Full fixed-point scale even for the exact constant: a tiny-mantissa table
  # would force table_concat to rebase the extension down to integer precision.
  ntab = MP.fp_normalize([r * s2, r * s2], -keep, keep)
  ms = r
  s = 1
  while s < cap_s
    kernel = MP.shift_kernel(s, s + 1, 3 * s + 1, keep)
    dvv, de = MP.table_concat(dtab, MP.fp_shift_values(dtab, kernel, keep))
    nvv, ne = MP.table_concat(ntab, MP.fp_shift_values(ntab, kernel, keep))
    # D' = Dl * Dr,  N' = Nl * Dr + M_s * Nr  (M_s scalar)
    nd = Array.new(2 * s + 1)
    nn = Array.new(2 * s + 1)
    (0..2 * s).each do |j|
      dr = dvv[2 * j + 1]
      t1v = nvv[2 * j] * dr
      t2v = ms * nvv[2 * j + 1]
      nd[j] = dvv[2 * j] * dr
      nn[j] = de >= 0 ? t1v + (t2v >> de) : (t1v >> -de) + t2v
    end
    dtab = MP.fp_normalize(nd, 2 * de, keep)
    ntab = MP.fp_normalize(nn, de >= 0 ? ne + de : ne, keep)
    ms *= ms
    s *= 2
  end
  [dtab, ntab, ms]
end

# gamma(x) for full-digit x in [0.5, 3] via the incomplete gamma series.
def incg_gamma(x, prec)
  prec2 = prec + 16
  raise ArgumentError unless x >= 0.5 && x <= 3

  lr = (prec2 + 20) * Math.log(10)
  r = (lr + 2 * Math.log(lr)).ceil + 4
  # Terms until the Poisson-like tail drops below 10**-(prec2+20):
  # solve gamma - (1+gamma)*log(1+gamma) = -q. (The Gaussian approximation
  # sqrt(2*r*q) underestimates the count by ~13% at q =~ r, costing a fixed
  # fraction of the precision.)
  q = Math.log(10) * (prec2 + 20) / r
  ga = 1.8
  5.times { ga -= (ga - (1 + ga) * Math.log(1 + ga) + q) / -Math.log(1 + ga) }
  nterms = ((1 + ga) * r).ceil + 32
  kappa = [(0.5 * Math.log2(nterms)).round, 1].max
  s_cap = 1 << kappa
  g = (nterms + s_cap - 1) / s_cap
  n_total = s_cap * g

  keep = G.drop_cap_bits(prec2) + $incg_guard_scale * s_cap * (n_total.bit_length + 4) + 256
  s2 = 1 << keep
  fd = [x.n_significant_digits - x.exponent, 0].max
  xa = (x._decimal_shift(fd).to_i << keep) / 10**fd

  dtab, ntab, ms = incg_value_tables(xa, s2, r, s_cap, keep)
  if g > s_cap + 1
    kernel = MP.shift_kernel(s_cap, s_cap + 1, g - s_cap - 1, keep)
    dtab = MP.table_concat(dtab, MP.fp_shift_values(dtab, kernel, keep))
    ntab = MP.table_concat(ntab, MP.fp_shift_values(ntab, kernel, keep))
  end
  dvals, ed = dtab
  nvals, en = ntab

  pw_nd = BigDecimal(2).power(en - ed, prec2)
  pw_c = BigDecimal(2).power(-ed, prec2)
  sum_series = BigDecimal(1)
  c_k = BigDecimal(1)
  g.times do |k|
    dk = BigDecimal(dvals[k]).mult(1, prec2)
    sum_series = sum_series.add(c_k.mult(BigDecimal(nvals[k]).mult(1, prec2), prec2).div(dk, prec2).mult(pw_nd, prec2), prec2)
    c_k = c_k.mult(ms, prec2).div(dk, prec2).mult(pw_c, prec2) if k < g - 1
  end

  rpow = BigDecimal(r).power(x, prec2)
  emr = BigMath.exp(BigDecimal(-r), prec2)
  rpow.mult(emr, prec2).mult(sum_series, prec2).div(x, prec)
end

def rel_err_exp(a, b, prec)
  e = a.sub(b, prec + 50).div(b, 10).abs
  e.zero? ? :exact : e.exponent
end

case ARGV[0] || 'acc'
when 'acc'
  [200, 500, 1000, 2000].each do |prec|
    { 'sqrt2' => BigDecimal(2).sqrt(2 * prec + 50),
      '1+sqrt2/3' => 1 + BigDecimal(2).sqrt(2 * prec + 50).div(3, 2 * prec + 50),
      '0.5001-ish' => BigDecimal('0.5') + BigDecimal(1).div(7, 2 * prec + 50)._decimal_shift(-3) }.each do |name, x|
      a = incg_gamma(x, prec)
      ref = BigMath.gamma(x, prec + 50)
      e = rel_err_exp(a, ref, prec)
      ok = e == :exact || e <= -(prec - 1)
      puts format('%s prec=%-5d %-10s rel_err_exp=%s', ok ? 'OK  ' : 'FAIL', prec, name, e)
    end
  end
when 'loss'
  $incg_guard_scale = 0
  [300, 500, 1000, 2000, 5000, 10_000].each do |prec|
    x = BigDecimal(2).sqrt(2 * prec + 100)
    ref = BigMath.gamma(x, prec + 100)
    a = incg_gamma(x, prec)
    prec2 = prec + 16
    lr = (prec2 + 20) * Math.log(10)
    r = (lr + 2 * Math.log(lr)).ceil + 4
    q = Math.log(10) * (prec2 + 20) / r
    ga = 1.8
    5.times { ga -= (ga - (1 + ga) * Math.log(1 + ga) + q) / -Math.log(1 + ga) }
    nterms = ((1 + ga) * r).ceil + 32
    s_cap = 1 << [(0.5 * Math.log2(nterms)).round, 1].max
    n_total = s_cap * ((nterms + s_cap - 1) / s_cap)
    e = a.sub(ref, prec + 100).div(ref, 10).abs
    achieved = e.zero? ? prec + 100 : -e.exponent
    loss = ((prec2 + 19 - achieved) * Math.log2(10)).round
    puts format('prec=%-6d S=%-4d bl=%-3d loss_bits=%-6d loss/(S*bl)=%.2f',
                prec, s_cap, n_total.bit_length, loss, loss.to_f / (s_cap * n_total.bit_length))
  end
when 'bench'
  [5000, 10_000, 20_000, 50_000].each do |prec|
    x = BigDecimal(2).sqrt(2 * prec + 50)
    ti = Benchmark.realtime { @a = incg_gamma(x, prec) }
    tg = Benchmark.realtime { @b = BigMath.gamma(x, prec) }
    puts format('prec=%-6d incgamma=%.2fs lagrange_mp=%.2fs (%.2fx) agree=%s',
                prec, ti, tg, tg / ti, rel_err_exp(@a, @b, prec))
    STDOUT.flush
  end
end
