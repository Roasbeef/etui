-module(gleam@javascript@array).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export_type([array/1]).

-type array(DJT) :: any() | {gleam_phantom, DJT}.

