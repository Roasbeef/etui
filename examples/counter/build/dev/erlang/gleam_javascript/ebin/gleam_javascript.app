{application, gleam_javascript, [
    {vsn, "1.0.1"},
    {applications, [gleam_stdlib]},
    {description, "Work with JavaScript types and values in Gleam, including promises!"},
    {modules, [gleam@javascript@array,
               gleam@javascript@promise,
               gleam@javascript@symbol]},
    {registered, []}
]}.
