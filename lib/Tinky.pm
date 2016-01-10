use v6;

module Tinky {

    class X::InvalidState is Exception {
        has $.state;
        has $.transition;
        method message() {
            "State '{ $!state.Str }' is not valid for Transition '{ $!transition.Str }'";
        }
    }

    class State {
        has Str $.name;

    }

    class Transition {
        has Str $.name;

        has State $.from;
        has State $.to;

    }

    role Object { ... };

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

        method apply-transition(Transition $trans) {
        }
    }
}
# vim: expandtab shiftwidth=4 ft=perl6
