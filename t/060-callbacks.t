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

my $trans = Tinky::Transition.new(name => 'test-transition', from => Tinky::State.new(name => "foo"), to => Tinky::State.new(name => "bar"));

$trans.validators.push: sub (ObjectOne $) returns Bool { True };
$trans.validators.push: sub (ObjectTwo $) returns Bool { False };

ok do {  await  $trans.validate(ObjectOne.new) }, "Transition.validate with a specific True validator";
nok do {  await $trans.validate(ObjectTwo.new) }, "Transition.validate with a specific False validator";
ok do {  await  $trans.validate(ObjectThree.new) }, "Transition.validate with no specific validator";

$trans.validators.push: sub (Tinky::Object $) returns Bool { False };

nok do {  await  $trans.validate(ObjectOne.new) }, "Transition.validate with a specific True validator but a non-specific False validator";
nok do {  await $trans.validate(ObjectTwo.new) }, "Transition.validate with a specific False validator but a non-specific False validator";
nok do {  await  $trans.validate(ObjectThree.new) }, "Transition.validate with no specific validator but a non-specific False validator";

$trans = Tinky::Transition.new(name => 'test-transition-2', from => Tinky::State.new(name => "foo-2"), to => Tinky::State.new(name => "bar-2"));

ok do {  await  $trans.validate-apply(ObjectOne.new) }, "Transition.validate-apply with no specific validators";
ok do {  await $trans.validate-apply(ObjectTwo.new) }, "Transition.validate-apply with no specific validators";
ok do {  await  $trans.validate-apply(ObjectThree.new) }, "Transition.validate-apply with no specific validators";

$trans.validators.push: sub (ObjectOne $) returns Bool { False };

nok do {  await  $trans.validate-apply(ObjectOne.new) }, "Transition.validate-apply with specific False validators on Transiion";
ok do {  await  $trans.validate-apply(ObjectTwo.new) }, "Transition.validate-apply with specific False validators on Transition on another object";
ok do {  await  $trans.validate-apply(ObjectThree.new) }, "Transition.validate-apply with specific False validators on Transiion on another object";

$trans.from.leave-validators.push: sub (ObjectTwo $) returns Bool { False };
nok do {  await  $trans.validate-apply(ObjectOne.new) }, "Transition.validate-apply with specific False validators on Transiion";
nok do {  await  $trans.validate-apply(ObjectTwo.new) }, "Transition.validate-apply with specific False validators on leave from";
ok do {  await  $trans.validate-apply(ObjectThree.new) }, "Transition.validate-apply with specific False validators on Transition on another object";

$trans.to.enter-validators.push: sub (ObjectThree $) returns Bool { False };
nok do {  await  $trans.validate-apply(ObjectOne.new) }, "Transition.validate-apply with specific False validators on Transiion";
nok do {  await  $trans.validate-apply(ObjectTwo.new) }, "Transition.validate-apply with specific False validators on leave from";
nok do {  await  $trans.validate-apply(ObjectThree.new) }, "Transition.validate-apply with specific False validators on enter to";

my @states = <one two three four>.map({ Tinky::State.new(name => $_) });
my @transitions = @states.rotor(2 => -1).map(-> ($from, $to) { my $name = $from.name ~ '-' ~ $to.name; Tinky::Transition.new(:$from, :$to, :$name) });

my $wf = Tinky::Workflow.new(:@transitions);

@transitions[0].validators.push: sub (ObjectOne $) returns Bool { False };

my $one = ObjectOne.new(state => @states[0]);
$one.apply-workflow($wf);

throws-like { $one.apply-transition(@transitions[0]) }, X::TransitionRejected, "transition rejected";

my $two = ObjectTwo.new(state => @states[0]);
$two.apply-workflow($wf);

lives-ok { $two.apply-transition(@transitions[0]) }, "another object is okay";

@transitions[1].to.enter-validators.push: sub (ObjectTwo $) returns Bool { False };

throws-like { $two.apply-transition(@transitions[1]) }, X::TransitionRejected, "transition rejected (with fail on to state)";

done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
