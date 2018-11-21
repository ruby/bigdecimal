#include "ruby.h"

VALUE rmpd_util_str_to_d(VALUE str);

void
Init_util(void)
{
  rb_define_method(rb_cString, "to_d", rmpd_util_str_to_d, 0);
}
