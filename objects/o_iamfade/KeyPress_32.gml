/// @description
test_reverse_next = !test_reverse_next;
test_patrol.Reverse(test_reverse_next);

if (test_patrol.IsFinished() ) { test_patrol.Play(); }