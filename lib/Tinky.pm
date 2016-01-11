use v6;

module Tinky {

    class X::InvalidState is Exception {
        has $.state;
        has $.transition;
        method message() {
            "State '{ $!state.Str }' is not valid for Transition '{ $!transition.Str }'";
        }
    }

    # Stub here, definition below
    class Transition { ... }
    role Object { ... };

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
        multi method ACCEPTS(State:D $state) {
            return self.from ~~ $state;
        }

        multi method ACCEPTS(Object:D $object) {
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

        multi method ACCEPTS(State:D $state) {
            return $!state ~~ $state;
        }

        multi method ACCEPTS(Transition:D $trans) {
            return $!state ~~ $trans;
        }

        method apply-transition(Transition $trans) {
        }
    }
}
# vim: expandtab shiftwidth=4 ft=perl6
