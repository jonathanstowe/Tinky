use v6;

=begin pod

=head1 NAME

Tinky - a basic and experimental Workflow/State Machine implementation

=head1 SYNOPSIS

=begin code

use Tinky;


# A class that will use the workflow
# it can have any attributes or methods
# required by your application

class Ticket does Tinky::Object {
    has Str $.ticket-number = (^100000).pick.fmt("%08d");
    has Str $.owner;
}

# Set up some states as required by the application
my $state-new         = Tinky::State.new(name => 'new');
my $state-open        = Tinky::State.new(name => 'open');
my $state-rejected    = Tinky::State.new(name => 'rejected');
my $state-in-progress = Tinky::State.new(name => 'in-progress');
my $state-stalled     = Tinky::State.new(name => 'stalled');
my $state-complete    = Tinky::State.new(name => 'complete');

# Each state has an 'enter-supply' and a 'leave-supply' which get the
# object which the state was applied to.

$state-rejected.enter-supply.act( -> $object { say "** sending rejected e-mail for Ticket '{ $object.ticket-number }' **"});

# Create some transitions to describe pre-determined change of state
# A method will be created on the Tinky::Object for each transition name

my $open              = Tinky::Transition.new(name => 'open', from => $state-new, to => $state-open);

# Where  more than one transition has the same name, the transition which matches the object's 
# current state will be use.
my $reject-new        = Tinky::Transition.new(name => 'reject', from => $state-new, to => $state-rejected);
my $reject-open       = Tinky::Transition.new(name => 'reject', from => $state-open, to => $state-rejected);
my $reject-stalled    = Tinky::Transition.new(name => 'reject', from => $state-stalled, to => $state-rejected);

my $stall-open        = Tinky::Transition.new(name => 'stall', from => $state-open, to => $state-stalled);
my $stall-progress    = Tinky::Transition.new(name => 'stall', from => $state-in-progress, to => $state-stalled);

# The transition supply allows specific logic for the transition to be performed

$stall-progress.supply.act( -> $object { say "** rescheduling tickets for '{ $object.owner }' on ticket stall **"});

my $unstall           = Tinky::Transition.new(name => 'unstall', from => $state-stalled, to => $state-in-progress);

my $take              = Tinky::Transition.new(name => 'take', from => $state-open, to => $state-in-progress);

my $complete-open     = Tinky::Transition.new(name => 'complete', from => $state-open, to => $state-complete);
my $complete-progress = Tinky::Transition.new(name => 'complete', from => $state-in-progress, to => $state-complete);

my @transitions = $open, $reject-new, $reject-open, $reject-stalled, $stall-open, $stall-progress, $unstall, $take, $complete-open, $complete-progress;

# The Workflow object allows the relation between states and transitions to be calculate
# and generates the methods that will be applied to the ticket object.  The initual-state
# will be applied to the object if there is no existing state on the state.
my $workflow = Tinky::Workflow.new(:@transitions, name => 'ticket-workflow', initial-state => $state-new );

# The workflow aggregates the Supplies of the transitions and the states.
# This could be to a logging subsystem for instance. 

$workflow.transition-supply.act(-> ($trans, $object) { say "Ticket '{ $object.ticket-number }' went from { $trans.from.name }' to '{ $trans.to.name }'" });

# The final-supply emits the state and the object when a state is reached where there are no
# further transitions available

$workflow.final-supply.act(-> ( $state, $object) { say "** updating performance stats with Ticket '{ $object.ticket-number }' entered State '{ $state.name }'" });

# Create an instance of the Tinky::Object.
# A 'state' can be supplied to initialise if, for example, the data was retrieved from a database.
my $ticket-a = Ticket.new(owner => "Operator A");

# Applying the workflow will set the initial state if one is configured and will
# apply a role that provides the transition methods.
# The workflow object can be configured to check whether the object to which it
# is being applied is suitable and throw an exception if not.

$ticket-a.apply-workflow($workflow);

# Exercise the transition methods.
# Other mechanisms are available for performing the transitions whuch may be more
# suitable if the next state is to be calculated.

# State new -> open
$ticket-a.open;

# State open -> in-progress
$ticket-a.take;

# Get the names of the states which are now available for the object
# [stalled complete]
$ticket-a.next-states>>.name.say;

# Directly assigning the state will be validated, an exception will
# be thrown if this is not a valid transition at the time
$ticket-a.state = $state-stalled;

# State stalled -> rejected
# This is a final state and no further transitions are available.
$ticket-a.reject;

=end code

There may be further example code in the C<examples> directory in the
distribution.

=head1 DESCRIPTION

Tinky is a deterministic state manager that can be used to implement a
workflow system, it provides a c<role> L<Tinky::Object> that allows an
object to have a managed state.

A L<Workflow|Tinky::Workflow> is simply a set of L<State|Tinky::State>s
and allowable transitions between them. Validators can be defined to check
whether an object should be allowed to enter or leave a specific state or
have a transition performed, asynchronous notification of state change
(enter, leave or transition application,) is provided by Supplies which
are available at L<State|Tinky::State>/L<Transition|Tinky::Transition>
level or aggregrated at the Workflow level.

=head2 class Tinky::State 

=head3 method enter

        method enter(Object:D $object) 

=head3 method validate-enter

        method validate-enter(Object $object) returns Promise 

=head3 method enter-supply

        method enter-supply()  returns Supply

=head3 method leave

        method leave(Object:D $object) 

=head3 method validate-leave

        method validate-leave(Object $object) returns Promise 

=head3 method leave-supply 

        method leave-supply() returns Supply

=head3 method Str

        method Str() 

=head3 method ACCEPTS

        multi method ACCEPTS(State:D $state) returns Bool 
        multi method ACCEPTS(Transition:D $transition) returns Bool 
        multi method ACCEPTS(Object:D $object) returns Bool 

=head2 class Tinky::Transition 

=head3 method applied

        method applied(Object:D $object) 

=head3 method validate

        method validate(Object:D $object) returns Promise 

=head3 method  validate-apply

        method validate-apply(Object:D $object) returns Promise 

=head3 method supply

        method supply() returns Supply 

=head3 method Str

        method Str() 

=head3 method ACCEPTS

        multi method ACCEPTS(State:D $state) returns Bool 
        multi method ACCEPTS(Object:D $object) returns Bool 

=head2 class Tinky::Workflow 

=head3  method states

        method states() 

=head3 method transitions-for-state

        method transitions-for-state(State:D $state ) returns Array[Transition]

=head3 method find-transition

        multi method find-transition(State:D $from, State:D $to) returns Transition

=head3 method validate-spply

        method validate-apply(Object:D $object) returns Promise 

=head3 method applied

        method applied(Object:D $object) 

=head3 method applied-supply

        method applied-supply() returns Supply 

=head3 method enter-supply

        method enter-supply() returns Supply 

=head3 method final-supply

        method final-supply() returns Supply 

=head3 method leave-supply

        method leave-supply() returns Supply 

=head3 method transition-supply


        method transition-supply() returns Supply 

=head3
        method role() 

=head2 role Tinky::Object 

=head3 method state

        method state(Object:D $SELF:) is rw 

=head3 method apply-workflow

        method apply-workflow(Workflow $wf) 

=head3 method apply-transition

        method apply-transition(Transition $trans) returns State 

=head3 method transitions

        method transitions() returns Array[Transition]

=head3 method next-states

        method next-states() returns Array[State]

=head3 method transition-for-state

        method transition-for-state(State:D $to-state) returns State

=head3 method ACCEPTS

        multi method ACCEPTS(State:D $state) returns Bool 
        multi method ACCEPTS(Transition:D $trans) returns Bool 

=head2 EXCEPTIONS

=head3 class Tinky::X::Fail is Exception 

=head3 class Tinky::X::Workflow is X::Fail

=head3 class Tinky::X::InvalidState is X::Workflow 

=head3 class Tinky::X::InvalidTransition is X::Workflow 

=head3 class Tinky::X::NoTransition is X::Fail 

=head3 class Tinky::X::NoWorkflow is X::Fail 

=head3 class Tinky::X::NoTransitions is X::Fail 

=head3 class Tinky::X::TransitionRejected is X::Fail 

=head3 class Tinky::X::ObjectRejected is X::Fail 

=head3 class Tinky::X::NoState is X::Fail 

=end pod

module Tinky:ver<0.0.1>:auth<github:jonathanstowe> {

    # Stub here, definition below
    class State      { ... };
    class Transition { ... }
    class Workflow   { ... };
    role Object      { ... };

    # Traits for user defined state and transition classes
    # The roles are only used to indicate the purpose of the
    # methods for the time being.

    my role EnterValidator { }
    multi sub trait_mod:<is> ( Method $m, :$enter-validator! ) is export {
        $m does EnterValidator;
    }

    my role LeaveValidator { }
    multi sub trait_mod:<is> (Method $m, :$leave-validator! ) is export {
        $m does LeaveValidator;
    }

    my role TransitionValidator { }
    multi sub trait_mod:<is> (Method $m, :$transition-validator! ) is export {
        $m does TransitionValidator;
    }

    my role ApplyValidator { }
    multi sub trait_mod:<is> (Method $m, :$apply-validator! ) is export {
        $m does ApplyValidator;
    }


    subset ValidateCallback of Callable where { $_.signature.params && $_.signature ~~ :(Object --> Bool) };

    # This doesn't need any state and can be used by both Transition and State
    # The @subs isn't constrained but they should be ValidateCallbacks
    my sub validate-helper(Object $object, @subs) returns Promise {
        my sub run(|c) {
            my @promises = do for @subs.grep( -> $v { c ~~ $v.signature  }) -> &callback {
                start { callback(|c) };
            }
            Promise.allof(@promises).then({ so all(@promises>>.result) })
        }
        run($object);
    }

    # find the methods in the supplied object, that would
    # accept the Object as an argument and then wrap them
    # as subs with the object to pass to the above
    my sub validate-methods(Mu:D $self, Object $object, ::Phase) {
        my @meths;
        for $self.^methods.grep(Phase) -> $meth {
            if $object.WHAT ~~ $meth.signature.params[1].type  {
                @meths.push: $meth.assuming($self);
            }
        }
        @meths;
    }

    class X::Fail is Exception {
    }

    class X::Workflow is X::Fail {
        has State       $.state;
        has Transition  $.transition;
    }

    class X::InvalidState is X::Workflow {
        method message() {
            "State '{ $.state.Str }' is not valid for Transition '{ $.transition.Str }'";
        }
    }

    class X::InvalidTransition is X::Workflow {
        has Str $.message;
        method message() {
            $!message // "Transition '{ $.transition.Str }' is not valid for State '{ $.state.Str }'";
        }
    }

    class X::NoTransition is X::Fail {
        has State $.from;
        has State $.to;
        has Str   $.message;
        method message() {
            $!message // "No Transition for '{ $.from.Str }' to '{ $.to.Str }'";
        }
    }

    class X::NoWorkflow is X::Fail {
        has Str $.message = "No workflow defined";

    }

    class X::NoTransitions is X::Fail {
        has Str $.message = "No Transitions defined in workflow";
    }

    class X::TransitionRejected is X::Fail {
        has Transition $.transition;
        method message() {
            "Transition '{ $!transition.Str }' was rejected by one or more validators";
        }
    }

    class X::ObjectRejected is X::Fail {
        has Workflow $.workflow;
        method message() {
            "The Workflow '{ $!workflow.Str }' rejected the object at apply";
        }
    }

    class X::NoState is X::Fail {
        has Str $.message = "No current state";
    }
    

    class State {
        has Str $.name is required;

        has Supplier $!enter-supplier  = Supplier.new;
        has Supplier $!leave-supplier  = Supplier.new;

        has ValidateCallback @.enter-validators;
        has ValidateCallback @.leave-validators;

        multi method ACCEPTS(State:D $state) returns Bool {
            # naive approach for the time being
            return self.name eq $state.name;
        }

        # define in terms of above so only need to change once
        multi method ACCEPTS(Transition:D $transition) returns Bool {
            return self ~~ $transition.from;
        }

        multi method ACCEPTS(Object:D $object) returns Bool {
            return self ~~ $object.state;
        }

        method Str() {
            $!name;
        }

        method validate-enter(Object $object) returns Promise {
            self!validate-phase('enter', $object);
        }

        method enter-supply() {
            $!enter-supplier.Supply;
        }
        method enter(Object:D $object) {
            $!enter-supplier.emit($object);
        }

        method validate-leave(Object $object) returns Promise {
            self!validate-phase('leave', $object);
        }

        method !validate-phase(Str $phase where 'enter'|'leave', Object $object) returns Promise {
            my @subs = do given $phase {
                when 'leave' {
                    (@!leave-validators, validate-methods(self, $object, LeaveValidator)).flat;
                }
                when 'enter' {
                    (@!enter-validators, validate-methods(self, $object, EnterValidator)).flat;
                }
            }
            validate-helper($object, @subs);
        }



        method leave-supply() {
            $!leave-supplier.Supply;
        }

        method leave(Object:D $object) {
            $!leave-supplier.emit($object);
        }
    }

    class Transition {
        has Str $.name;

        has State $.from;
        has State $.to;

        has Supplier $!supplier = Supplier.new;

        has ValidateCallback @.validators;

        # defined in terms of State so we only need to change once
        multi method ACCEPTS(State:D $state) returns Bool {
            return self.from ~~ $state;
        }

        multi method ACCEPTS(Object:D $object) returns Bool {
            return self.from ~~ $object.state;
        }

        method applied(Object:D $object) {
            self.from.leave($object);
            self.to.enter($object);
            $!supplier.emit($object);
        }

        # This just calls the validators for the Transition
        method validate(Object:D $object) returns Promise {
            validate-helper($object, ( @!validators, validate-methods(self, $object, TransitionValidator)).flat);
        }

        method validate-apply(Object:D $object) returns Promise {
            my @promises = (self.validate($object), self.from.validate-leave($object), self.to.validate-enter($object));
            Promise.allof(@promises).then({ so all(@promises>>.result)});
        }

        method supply() returns Supply {
            $!supplier.Supply;
        }

        method Str() {
            $!name;
        }

    }


    class Workflow {

        has Str $.name;

        has State      @.states;
        has Transition @.transitions;

        has State      $.initial-state;

        has ValidateCallback @.validators;

        method validate-apply(Object:D $object) returns Promise {
            validate-helper($object, ( @!validators, validate-methods(self, $object, ApplyValidator)).flat);
        }

        has $!role;

        method states() {
            if not @!states.elems {
                if @!transitions {
                    @!states = @!transitions.map({ $_.from, $_.to }).flat.unique;
                }
                else {
                    X::NoTransitions.new.throw;
                }
            }
            @!states;
        }

        has Supplier $!applied-supplier = Supplier.new;

        method applied(Object:D $object) {
            $!applied-supplier.emit($object);
        }

        method applied-supply() returns Supply {
            $!applied-supplier.Supply;
        }

        has Supply $!enter-supply;
        method enter-supply() returns Supply {
            $!enter-supply //= do {
                my @supplies = self.states.map(-> $state { $state.enter-supply.map(-> $value { $state, $value }) });
                Supply.merge(@supplies);
            }
            $!enter-supply;
        }
        
        has Supply $!final-supply;
        method final-supply() returns Supply {
            $!final-supply //= self.enter-supply.grep( -> $ ($state, $object) { !?self.transitions-for-state($state) } );
        }

        has Supply $!leave-supply;
        method leave-supply() returns Supply {
            $!leave-supply //= do {
                my @supplies = self.states.map(-> $state { $state.leave-supply.map(-> $value { $state, $value }) });
                Supply.merge(@supplies);
            }
            $!leave-supply;
        }

        has Supply $!transition-supply;
        method transition-supply() returns Supply {
            $!transition-supply //= do {
                my @supplies = self.transitions.map( -> $transition { $transition.supply.map(-> $value { $transition, $value }) });
                Supply.merge(@supplies);
            }
            $!transition-supply;
        }

        method transitions-for-state(State:D $state ) {
            @!transitions.grep($state);
        }

        # I'm half tempted to have this throw if there is more than one
        multi method find-transition(State:D $from, State:D $to) {
            return self.transitions-for-state($from).first({ $_.to ~~ $to }); 
        }

        method role() {
            if not ?$!role.HOW.archetypes.composable {
                $!role = role { };
                for @.transitions.classify(-> $t { $t.name }).kv -> $name, $transitions {
                    my $method = method () {
                        if $transitions.grep(self.state).first -> $tran {
                            self.apply-transition($tran);
                        }
                        else {
                            X::InvalidTransition.new(message => "No transition '$name' for state '{ self.state.Str }'").throw;
                        }
                    }
                    $!role.^add_method($name, $method);
                }
            }
            $!role;
        }
    }

    role Object {
        has Workflow $!workflow;

        has State $.state;

        method !state() is rw returns State {
            $!state;
        }

        method state(Object:D $SELF:) is rw {
            Proxy.new(
                FETCH => method () {
                    $SELF!state;
                },
                STORE => method (State $val) {
                    if not $SELF!state.defined {
                        $SELF!state = $val;
                    }
                    else {
                        if $SELF.transition-for-state($val) -> $trans {
                            $SELF.apply-transition($trans);
                        }
                        else {
                            X::NoTransition.new(from => $SELF.state, to => $val).throw;
                        }
                    }
                    $SELF!state;
                }
            );
        }

        method apply-workflow(Workflow $wf) {
            if await $wf.validate-apply(self) {
                $!workflow = $wf;
                if not $!state.defined and $!workflow.initial-state.defined {
                    $!state = $!workflow.initial-state;
                }
                try self does $wf.role;
                $wf.applied(self);;
            }
            else {
                X::ObjectRejected.new(workflow => $wf).throw;
            }
        }

        multi method ACCEPTS(State:D $state) returns Bool {
            return $!state ~~ $state;
        }

        multi method ACCEPTS(Transition:D $trans) returns Bool {
            return $!state ~~ $trans;
        }

        method transitions() {
            my @trans;
            if $!workflow.defined {
                @trans = $!workflow.transitions-for-state($!state);
            }
            else {
                X::NoWorkflow.new.throw;
            }
            @trans;
        }

        method next-states() {
            my @states = self.transitions>>.to;
            @states;
        }

        method transition-for-state(State:D $to-state) {
            my $trans;
            if $!workflow.defined {
                $trans = $!workflow.find-transition($!state, $to-state);
            }
            else {
                X::NoWorkflow.new.throw;
            }
            $trans;
        }

        method apply-transition(Transition $trans) returns State {
            if $!state.defined {
                if self ~~ $trans {
                    if await $trans.validate-apply(self) {
                        $!state = $trans.to;
                        $trans.applied(self);
                        $!state;
                    }
                    else {
                        X::TransitionRejected.new(transition => $trans).throw;
                    }
                }
                else {
                    if $!state.defined {
                        X::InvalidTransition.new(state => $!state, transition => $trans).throw;
                    }
                    else {
                        X::NoState.new.throw;
                    }

                }
            }
            else {
                X::NoState.new.throw;
            }
        }
    }
}
# vim: expandtab shiftwidth=4 ft=perl6
