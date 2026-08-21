{application, minimal, [
    {vsn, "1.0.0"},
    {applications, [etui,
                    gleam_stdlib,
                    gleeunit]},
    {description, "Minimal étui app: hello world, quit with q"},
    {modules, [minimal,
               minimal@@main]},
    {registered, []}
]}.
