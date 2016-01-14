use v6;

=begin pod

=head1 NAME

Tinky - a basic and experimental Workflow/State Machine implementation

=head1 SYNOPSIS

=head1 DESCRIPTION

=end pod

module Tinky {

    # Stub here, definition below
    class State      { ... };
    class Transition { ... }
    class Workflow   { ... };
    role Object      { ... };

    # Traits for user defined state and transition classes
    # The roles are only used to indicate the purpose of the
    # methods for the time being.

    role EnterValidator { }
    multi sub trait_mod:<is> ( Method $m, :$enter-validator! ) is export {
        $m does EnterValidator;
    }

    role LeaveValidator { }
    multi sub trait_mod:<is> (Method $m, :$leave-validator! ) is export {
        $m does LeaveValidator;
    }

    role TransitionValidator { }
    multi sub trait_mod:<is> (Method $m, :$transition-validator! ) is export {
        $m does TransitionValidator;
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
        method message() {
            "Transition '{ $.transition.Str }' is not valid for State '{ $.state.Str }'";
        }
    }

    class X::NoTransition is X::Fail {
        has State $.from;
        has State $.to;
        method message() {
            "No Transition for '{ $.from.Str }' to '{ $.to.Str }'";
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

        has Mu $!role;

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
            if not $!role.^name ne 'Mu' {
                $!role = role { };

                for @.transitions -> $tran {
                    $!role.^add_method($tran.name, method (Object:D:) {
                        self.apply-transition($tran);
                    });
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
            $!workflow = $wf;
            self does $wf.role;
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
