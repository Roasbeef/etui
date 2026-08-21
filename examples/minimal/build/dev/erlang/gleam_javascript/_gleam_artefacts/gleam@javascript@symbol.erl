-module(gleam@javascript@symbol).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export_type([symbol/0]).

-type symbol() :: any().

