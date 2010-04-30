use inc::Module::Install;
name 'AnyEvent-HTTP-Simple';
all_from 'lib/AnyEvent/HTTP/Simple.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
