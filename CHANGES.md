# CHANGES

## 3.1.1

* Fix the result precision of `BigDecimal#divmod`. [GH-219]

  **Kenta Murata**

## 3.1.0

* Improve documentation [GH-209]

  **Burdette Lamar**

* Let BigDecimal#quo accept precision. [GH-214] [Bug #8826]

  Reported by Földes László

* Allow passing both float and precision in BigDecimal#div. [GH-212] [Bug #8826]

  Reported by Földes László

* Add `BigDecimal#scale` and `BigDecimal#precision_scale`

  **Kenta Murata**

* Fix a bug of `BigDecimal#precision` for the case that a BigDecimal has single internal digit [GH-205]

  **Kenta Murata**

* Fix segmentation fault due to a bug of `VpReallocReal`

  **Kenta Murata**

* Use larger precision in divide for irrational or recurring results. [GH-94] [Bug #13754]

  Reported by Lionel PERRIN

* Fix negative Bignum conversion [GH-196]

  **Jean byroot Boussier**

* Fix grammar in error messages. [GH-196]

  **Olle Jonsson**

* Improve the conversion speed of `Kernel#BigDecimal` and `to_d` methods.

  **Kenta Murata**

* Fix trailing zeros handling in `rb_uint64_convert_to_BigDecimal`. [GH-192]

  Reported by @kamipo

* Permit 0 digits in `BigDecimal(float)` and `Float#to_d`.
  It means auto-detection of the smallest number of digits to represent
  the given Float number without error. [GH-180]

  **Kenta Murata**

* Fix precision issue of Float. [GH-70] [Bug #13331]

  Reported by @casperisfine

## 3.0.2

*This version is totally same as 3.0.0.  This was released for reverting 3.0.1.*

* Revert the changes in 3.0.1 due to remaining bugs.

## 3.0.1

*This version is yanked due to the remaining bugs.*

## 3.0.0

* Deprecate `BigDecimal#precs`.

  **Kenta Murata**

* Add `BigDecimal#n_significant_digits`.

  **Kenta Murata**

* Add `BigDecimal#precision`.

  **Kenta Murata**

* Ractor support.

  **Kenta Murata**

* Fix a bug of the way to undefine `allocate` method.

  **Kenta Murata**

* FIx the defaullt precision of `Float#to_d`.
  [Bug #13331]

  **Kenta Murata**

## 2.0.2

* Deprecate taint/trust and related methods, and make the methods no-ops

  **Jeremy Evans**

* Make BigDecimal#round with argument < 1 return Integer

  **Jeremy Evans**

* Use higher default precision for BigDecimal#power and #**

  **Jeremy Evans**
  **Kenta Murata**

## 2.0.1

* Let BigDecimal#to_s return US-ASCII string

  **Kenta Murata**

## 2.0.0

* Remove `BigDecimal.new`

  **Kenta Murata**

* Drop fat-gem support

  **Akira Matsuda**

* Do not mutate frozen BigDecimal argument in BigMath.exp

  **Jeremy Evans**

* Make Kernel#BigDecimal return argument if given correct type
  [Bug #7522]

  **Jeremy Evans**

* Undef BigDecimal#initialize_copy

  **Jeremy Evans**

* Support conversion from Complex without the imaginary part

  **Kenta Murata**

* Remove taint checking

  **Jeremy Evans**

* Code maintenance

  **Nobuyoshi Nakada**

## 1.4.4

* Fix String#to_d against the string with trailing "e" like "1e"

  **Ibrahim Awwal**

* Add BigDecimal.interpret_loosely, use it in String#to_d,
  and remove bigdecimal/util.so and rmpd_util_str_to_d

  **Kenta Murata**

## 1.4.3

* Restore subclassing support

  **Kenta Murata**

## 1.4.2

* Fix gem installation issue on mingw32.

  **Kenta Murata**

## 1.4.1

* Fix wrong packaging.

  **Ben Ford**

## 1.4.0

* Update documentation of `exception:` keyword.

  **Victor Shepelev**

* Fix VpAlloc so that '1.2.3'.to_d is 1.2

  **Nobuyoshi Nakada**

* Restore `BigDecimal.new` just for version 1.4 for very old version of Rails

  **Kenta Murata**

* Support `exception:` keyword in `BigDecimal()`

  **Kenta Murata**

* Remove `BigDecimal#initialize`

  **Kenta Murata**

* Fix the string parsing logic in `BigDecimal()` to follow `Float()`

  **Kenta Murata**

* Fix `String#to_d` to follow `String#to_f`

  **Kenta Murata**

* Update `BigDecimal#inspect` documentation

  **Dana Sherson**

* Remove `BigDecimal.ver`, `BigDecimal.allocate`, and `BigDecimal.new`

  **Kenta Murata**

* No more support Ruby < 2.3

  **Kenta Murata**

* Make BigDecimal objects frozen

  **Kenta Murata**

* Remove division by zero from the internal implementation

  **Urabe, Shyouhei**

## 1.3.5

* Add NilClass#to_d

  **Jose Ramon Camacho**

## 1.3.4

* Stop deprecation warning in dup and clone, and just return self

  **Kenta Murata**

* Improve warning message in BigDecimal.new

  **Masataka Pocke Kuwabara**

## 1.3.3

* Introduce BigDecimal::VERSION, deprecate BigDecimal.ver, and follow this version string to gem's version.

  **Kenta Murata**

* Deprecate BigDecimal.new

  **Kenta Murata**

* Deprecate BigDecimal#clone and #dup

  **Kenta Murata**

* Relax the dependent version of rake-compiler

  **yui-knk**

* Works for better windows cross-compilation support

  **SHIBATA Hiroshi**

* Use Bundler::GemHelper.install_tasks instead of bundler/gem_tasks

  **SHIBATA Hiroshi**

* Remove the old gemspec file

  **yui-knk**

* Fix for mathn removal in Ruby 2.5

  **SHIBATA Hiroshi**

* Update ruby versions in .travis.yml

  **Jun Aruga**

* Add tests for BigDecimal#truncate

  **yui-knk**

* Add tests for BigDecimal#round

  **yui-knk**

* Fix error message for precision argument

  **Marcus Stollsteimer**

## 1.3.2 and older

Omitted.
