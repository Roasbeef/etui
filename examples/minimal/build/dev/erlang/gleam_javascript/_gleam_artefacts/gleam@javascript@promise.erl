-module(gleam@javascript@promise).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export_type([promise/1]).

-type promise(DKX) :: any() | {gleam_phantom, DKX}.

