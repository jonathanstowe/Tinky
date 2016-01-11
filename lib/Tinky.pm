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
    


    class State {
        has Str $.name is required;

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
    }


    class Workflow {

        has Str $.name;

        has State      @.states;
        has Transition @.transitions;

        has Mu $!role;

        method role() {
            if not $!role.defined {
                $!role = role { };

                for @.transitions -> $tran {
                    $!role.^add_method($tran.name, method {
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

        method apply-transition(Transition $trans) returns State {
            if self ~~ $trans {
                $!state = $trans.to;
            }
            else {
                X::InvalidTransition.new(state => $!state, transition => $trans).throw;
            }
        }
    }
}
# vim: expandtab shiftwidth=4 ft=perl6
