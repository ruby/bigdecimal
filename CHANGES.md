# CHANGES

## master

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
