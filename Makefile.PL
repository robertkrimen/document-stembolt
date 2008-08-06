use inc::Module::Install;

name 'Document-Stembolt';
all_from 'lib/Document/Stembolt.pm';

build_requires 'Test::More';

auto_install;

WriteAll;

