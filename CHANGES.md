# CHANGES

## master

* Remove `BigDecimal.new`

  **Kenta Murata**

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
