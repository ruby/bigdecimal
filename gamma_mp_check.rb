# Check & benchmark for the experimental multipoint gamma (gamma_multipoint.rb)
# Usage: ruby -Ilib -Itmp/arm64-darwin24/stage/lib gamma_mp_check.rb [mode]
#   mode: acc (default) | bench | debug
#   MP_EVAL=fast|horner forces the evaluation mode
require 'bigdecimal'
require 'bigdecimal/math'
require 'bigdecimal/math/gamma'
require 'benchmark'

MP = BigMath.const_get(:Gamma)::Multipoint
MP.eval_mode = ENV['MP_EVAL'].to_sym if ENV['MP_EVAL']
MP.engine = ENV['MP_ENGINE'].to_sym if ENV['MP_ENGINE']
abort 'multipoint is disabled (Integer::GMP_VERSION not found)' unless MP.enabled
MP.min_prec = 1 # exercise the multipoint path at every precision

def bsgs_gamma(x, prec)
  MP.enabled = false
  BigMath.gamma(x, prec)
ensure
  MP.enabled = true
end

def rel_err_exp(a, b, prec)
  e = a.sub(b, prec + 50).div(b, 10).abs
  e.zero? ? :exact : e.exponent
end

mode = ARGV[0] || 'acc'

case mode
when 'debug'
  prec = 50
  x = BigDecimal(2).sqrt(150)
  a = BigMath.gamma(x, prec)
  b = bsgs_gamma(x, prec + 20)
  puts "mp  = #{a.to_s("F")[0, 60]}"
  puts "ref = #{b.to_s("F")[0, 60]}"
  puts "rel_err_exp = #{rel_err_exp(a, b, prec)}"
when 'acc'
  [100, 200, 500, 1000, 2000].each do |prec|
    cases = {
      "sqrt2" => BigDecimal(2).sqrt(2 * prec + 50),
      "1/3" => BigDecimal(1).div(3, 2 * prec + 50),
      "near-node 7+eps" => BigDecimal(7) + BigDecimal(1).div(3, prec + 50)._decimal_shift(-(prec / 2)),
      "0.6" => BigDecimal("0.6") + BigDecimal(1).div(7, 2 * prec + 50)._decimal_shift(-3),
      "reflect sqrt2/3" => BigDecimal(2).sqrt(2 * prec + 50).div(3, 2 * prec + 50),
      "reflect -sqrt2" => -BigDecimal(2).sqrt(2 * prec + 50),
    }
    cases.each do |name, x|
      t_mp = Benchmark.realtime { @mp = BigMath.gamma(x, prec) }
      ref = bsgs_gamma(x, prec + 50)
      e = rel_err_exp(@mp, ref, prec)
      ok = e == :exact || e <= -prec
      puts format("%s prec=%-5d %-16s rel_err_exp=%-6s mp=%.2fs", ok ? "OK  " : "FAIL", prec, name, e, t_mp)
    end
  end
when 'bench'
  [2000, 5000, 10000].each do |prec|
    x = BigDecimal(2).sqrt(2 * prec + 50)
    t_mp = Benchmark.realtime { @mp = BigMath.gamma(x, prec) }
    t_ref = Benchmark.realtime { @ref = bsgs_gamma(x, prec) }
    refhi = bsgs_gamma(x, prec + 50)
    puts format("prec=%-6d mp=%.2fs bsgs=%.2fs (%.1fx) mp_err=%s bsgs_err=%s",
                prec, t_mp, t_ref, t_ref / t_mp, rel_err_exp(@mp, refhi, prec), rel_err_exp(@ref, refhi, prec))
  end
end
