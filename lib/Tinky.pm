use v6;

=begin pod

=head1 NAME

Tinky - a basic and experimental Workflow/State Machine implementation

=head1 SYNOPSIS

=head1 DESCRIPTION

=end pod

module Tinky {

    # Stub here, definition below
    class State { ... };
    class Transition { ... }
    class Workflow { ... };
    role Object { ... };

    class X::Workflow is Exception {
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

    class X::NoTransition is Exception {
        has State $.from;
        has State $.to;
        method message() {
            "No Transition for '{ $.from.Str }' to '{ $.to.Str }'";
        }
    }

    class X::NoWorkflow is Exception {
        has Str $.message = "No workflow defined";

    }

    class X::NoTransitions is Exception {
        has Str $.message = "No Transitions defined in workflow";
    }
    


    class State {
        has Str $.name is required;

        has Supplier $!enter-supplier = Supplier.new;
        has Supplier $!leave-supplier  = Supplier.new;

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

        method enter-supply() {
            $!enter-supplier.Supply;
        }
        method enter(Object:D $object) {
            $!enter-supplier.emit($object);
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
        method enter-supply() {
            $!enter-supply //= do {
                my @supplies = self.states.map(-> $state { $state.enter-supply.map(-> $value { $state, $value }) });
                Supply.merge(@supplies);
            }
            $!enter-supply;
        }

        has Supply $!leave-supply;
        method leave-supply() {
            $!leave-supply //= do {
                my @supplies = self.states.map(-> $state { $state.leave-supply.map(-> $value { $state, $value }) });
                Supply.merge(@supplies);
            }
            $!leave-supply;
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
            if self ~~ $trans {
                # Needs to be through the proxy here
                $!state = $trans.to;
                $trans.applied(self);
                $!state;
            }
            else {
                X::InvalidTransition.new(state => $!state, transition => $trans).throw;
            }
        }
    }
}
# vim: expandtab shiftwidth=4 ft=perl6
