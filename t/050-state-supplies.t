#!perl6

use v6;

use Test;

use Tinky;

my @states = <one two three four>.map({ Tinky::State.new(name => $_) });

for @states -> $state {
    $state.enter-supply.tap({does-ok $_, Tinky::Object, "got an Object from enter supply"; });
    $state.leave-supply.tap({ does-ok $_, Tinky::Object, "got an Object from leave supply" });
}

my @transitions = @states.rotor(2 => -1).map(-> ($from, $to) { my $name = $from.name ~ '-' ~ $to.name; Tinky::Transition.new(:$from, :$to, :$name) });

class FooTest does Tinky::Object { }

throws-like { Tinky::Workflow.new.states }, X::NoTransitions, ".states throws if there aren't any transitions";

my Tinky::Workflow $wf;

lives-ok { $wf = Tinky::Workflow.new(:@transitions) }, "create new workflow with transitions";

my @enter;
my @leave;

my $obj = FooTest.new();
$obj.apply-workflow($wf);

lives-ok { $wf.enter-supply.act( -> $ ( $state, $object) { @enter.push($state.name); }) }, "set up tap on enter-supply";
lives-ok { $wf.enter-supply.act( -> $ ( $state, $object) {isa-ok $state, Tinky::State }) }, "set up tap on enter-supply";
lives-ok { $wf.leave-supply.act( -> $ ( $state, $object) { @leave.push($state.name); }) }, "set up tap on leave-supply";
lives-ok { $wf.leave-supply.act(-> $ ( $state, $obj ) { isa-ok $state, Tinky::State } ) }, "set up tap on leave-supply";

for @states -> $state {
    my $old-state = $obj.state;
    lives-ok { $obj.state = $state }, "set state to '{ $state.name }' by assigning to current-state";
    ok $obj.state ~~ $state , "and it is the expected state";
}

is-deeply @enter, [<two three four>], "got the right enter events";
is-deeply @leave, [<one two three>], "got the right leave events";

done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
