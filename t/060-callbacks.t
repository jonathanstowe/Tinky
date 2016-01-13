#!perl6

use v6;

use Test;

use Tinky;

class ObjectOne does Tinky::Object {
}

class ObjectTwo does Tinky::Object {
}

class ObjectThree does Tinky::Object {
}

my Tinky::State $state_one = Tinky::State.new(name => 'one');

$state_one.enter-validators.push: sub (ObjectOne $) returns Bool { True };
$state_one.enter-validators.push: sub (ObjectTwo $) returns Bool { False };

ok do {  await  $state_one.validate-enter(ObjectOne.new) }, "validate-enter with a specific True validator";
nok do {  await $state_one.validate-enter(ObjectTwo.new) }, "validate-enter with a specific False validator";
ok do {  await  $state_one.validate-enter(ObjectThree.new) }, "validate-enter with no specific validator";

$state_one.leave-validators.push: sub (ObjectOne $) returns Bool { True };
$state_one.leave-validators.push: sub (ObjectTwo $) returns Bool { False };

ok do {  await  $state_one.validate-leave(ObjectOne.new) }, "validate-leave with a specific True validator";
nok do {  await $state_one.validate-leave(ObjectTwo.new) }, "validate-leave with a specific False validator";
ok do {  await  $state_one.validate-leave(ObjectThree.new) }, "validate-leave with no specific validator";


done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
