-module(etui@widgets@scene).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([scene_new/1, with_bg/2, render/4]).
-export_type([scene_fill/0, shape/0, scene/0]).

-type scene_fill() :: {scene_solid, etui@style:color()} | {scene_gradient, list(etui@style:color())} | scene_rainbow | scene_animated_rainbow.

-type shape() :: {circle_outline, integer(), integer(), integer(), scene_fill()} | {disc, integer(), integer(), integer(), scene_fill()} | {planet, integer(), integer(), integer(), integer(), scene_fill(), integer()} | {mandelbrot, integer()}.

-type scene() :: {scene, list(shape()), etui@style:color()}.

-file("src/etui/widgets/scene.gleam", 47).
-spec scene_new(list(shape())) -> scene().
scene_new(Shapes) ->
    {scene, Shapes, default}.

-file("src/etui/widgets/scene.gleam", 51).
-spec with_bg(scene(), etui@style:color()) -> scene().
with_bg(S, Bg) ->
    {scene, erlang:element(2, S), Bg}.

-file("src/etui/widgets/scene.gleam", 372).
-spec mandelbrot_iter(integer(), integer(), integer(), integer(), integer(), integer()) -> integer().
mandelbrot_iter(Cr, Ci, Zr, Zi, Iter, Max_iter) ->
    case Iter >= Max_iter of
        true ->
            Iter;

        false ->
            Zr2 = (Zr * Zr) div 1024,
            Zi2 = (Zi * Zi) div 1024,
            case (Zr2 + Zi2) > 4096 of
                true ->
                    Iter;

                false ->
                    mandelbrot_iter(Cr, Ci, (Zr2 - Zi2) + Cr, (((2 * Zr) * Zi) div 1024) + Ci, Iter + 1, Max_iter)
            end
    end.

-file("src/etui/widgets/scene.gleam", 344).
-spec mandelbrot_cols(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), integer(), integer(), integer(), integer(), integer(), integer()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
mandelbrot_cols(Pixels, Pw, Pw1, Max_iter, By, Ci, Bx) ->
    case Bx >= Pw of
        true ->
            Pixels;

        false ->
            Cr = -2560 + case Pw1 of
                0 ->
                    0;

                _value ->
                    (Bx * 3584) div _value
            end,
            Iter = mandelbrot_iter(Cr, Ci, 0, 0, 0, Max_iter),
            Pixels@1 = case Iter >= Max_iter of
                true ->
                    Pixels;

                false ->
                    Hue = case Max_iter of
                        0 ->
                            0;

                        _value@1 ->
                            (Iter * 300) div _value@1
                    end,
                    Fg = etui@color:hue_to_rgb(Hue),
                    etui@braille:put(Pixels, Bx, By, Fg)
            end,
            mandelbrot_cols(Pixels@1, Pw, Pw1, Max_iter, By, Ci, Bx + 1)
    end.

-file("src/etui/widgets/scene.gleam", 324).
-spec mandelbrot_rows(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), integer(), integer(), integer(), integer(), integer(), integer()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
mandelbrot_rows(Pixels, Pw, Ph, Pw1, Ph1, Max_iter, By) ->
    case By >= Ph of
        true ->
            Pixels;

        false ->
            Ci = 1280 - case Ph1 of
                0 ->
                    0;

                _value ->
                    (By * 2560) div _value
            end,
            Pixels@1 = mandelbrot_cols(Pixels, Pw, Pw1, Max_iter, By, Ci, 0),
            mandelbrot_rows(Pixels@1, Pw, Ph, Pw1, Ph1, Max_iter, By + 1)
    end.

-file("src/etui/widgets/scene.gleam", 310).
-spec draw_mandelbrot(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), integer(), integer(), integer()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
draw_mandelbrot(Pixels, Pw, Ph, Max_iter) ->
    Pw1 = gleam@int:max(1, Pw - 1),
    Ph1 = gleam@int:max(1, Ph - 1),
    mandelbrot_rows(Pixels, Pw, Ph, Pw1, Ph1, Max_iter, 0).

-file("src/etui/widgets/scene.gleam", 405).
-spec scene_color(scene_fill(), integer(), integer(), integer(), integer()) -> etui@style:color().
scene_color(Fill, Px, Pw, Frame, Period) ->
    P = gleam@int:max(1, Period),
    W = gleam@int:max(1, Pw),
    case Fill of
        {scene_solid, C} ->
            C;

        {scene_gradient, Stops} ->
            etui@color:gradient(Stops, Px, W - 1);

        scene_rainbow ->
            etui@color:hue_to_rgb(case W of
                0 ->
                    0;

                _value ->
                    (Px * 360) div _value
            end);

        scene_animated_rainbow ->
            etui@color:hue_to_rgb((case W of
                0 ->
                    0;

                _value@1 ->
                    (Px * 360) div _value@1
            end + case P of
                0 ->
                    0;

                _value@2 ->
                    (Frame * 360) div _value@2
            end) rem 360)
    end.

-file("src/etui/widgets/scene.gleam", 203).
-spec disc_dy_loop(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), integer(), integer(), integer(), scene_fill(), integer(), integer(), integer(), integer(), integer(), integer()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
disc_dy_loop(Pixels, Cx, Cy, R, Fill, Pw, Ph, Frame, Period, Dx, Dy) ->
    case Dy > R of
        true ->
            Pixels;

        false ->
            Pixels@1 = case ((Dx * Dx) + (Dy * Dy)) =< (R * R) of
                false ->
                    Pixels;

                true ->
                    Bx = Cx + Dx,
                    By = Cy + Dy,
                    case (((Bx >= 0) andalso (By >= 0)) andalso (Bx < Pw)) andalso (By < Ph) of
                        false ->
                            Pixels;

                        true ->
                            Fg = scene_color(Fill, Bx, Pw, Frame, Period),
                            etui@braille:put(Pixels, Bx, By, Fg)
                    end
            end,
            disc_dy_loop(Pixels@1, Cx, Cy, R, Fill, Pw, Ph, Frame, Period, Dx, Dy + 1)
    end.

-file("src/etui/widgets/scene.gleam", 181).
-spec disc_dx_loop(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), integer(), integer(), integer(), scene_fill(), integer(), integer(), integer(), integer(), integer()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
disc_dx_loop(Pixels, Cx, Cy, R, Fill, Pw, Ph, Frame, Period, Dx) ->
    case Dx > R of
        true ->
            Pixels;

        false ->
            Pixels@1 = disc_dy_loop(Pixels, Cx, Cy, R, Fill, Pw, Ph, Frame, Period, Dx, 0 - R),
            disc_dx_loop(Pixels@1, Cx, Cy, R, Fill, Pw, Ph, Frame, Period, Dx + 1)
    end.

-file("src/etui/widgets/scene.gleam", 167).
-spec draw_disc(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), integer(), integer(), integer(), scene_fill(), integer(), integer(), integer(), integer()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
draw_disc(Pixels, Cx, Cy, R, Fill, Pw, Ph, Frame, Period) ->
    disc_dx_loop(Pixels, Cx, Cy, R, Fill, Pw, Ph, Frame, Period, 0 - R).

-file("src/etui/widgets/scene.gleam", 270).
-spec cos_sin_256(integer()) -> {integer(), integer()}.
cos_sin_256(Step) ->
    case Step rem 32 of
        0 ->
            {256, 0};

        1 ->
            {251, 50};

        2 ->
            {236, 98};

        3 ->
            {213, 142};

        4 ->
            {181, 181};

        5 ->
            {142, 213};

        6 ->
            {98, 236};

        7 ->
            {50, 251};

        8 ->
            {0, 256};

        9 ->
            {-50, 251};

        10 ->
            {-98, 236};

        11 ->
            {-142, 213};

        12 ->
            {-181, 181};

        13 ->
            {-213, 142};

        14 ->
            {-236, 98};

        15 ->
            {-251, 50};

        16 ->
            {-256, 0};

        17 ->
            {-251, -50};

        18 ->
            {-236, -98};

        19 ->
            {-213, -142};

        20 ->
            {-181, -181};

        21 ->
            {-142, -213};

        22 ->
            {-98, -236};

        23 ->
            {-50, -251};

        24 ->
            {0, -256};

        25 ->
            {50, -251};

        26 ->
            {98, -236};

        27 ->
            {142, -213};

        28 ->
            {181, -181};

        29 ->
            {213, -142};

        30 ->
            {236, -98};

        _ ->
            {251, -50}
    end.

-file("src/etui/widgets/scene.gleam", 258).
-spec orbit_position(integer(), integer(), integer(), integer(), integer()) -> {integer(), integer()}.
-doc(~" 32-step integer orbit using precomputed cos/sin × 256.").
orbit_position(Cx, Cy, R, Frame, Period) ->
    Step = case gleam@int:max(1, Period) of
        0 ->
            0;

        _value ->
            (Frame * 32) div _value
    end rem 32,
    {C256, S256} = cos_sin_256(Step),
    {Cx + ((R * C256) div 256), Cy + ((R * S256) div 256)}.

-file("src/etui/widgets/scene.gleam", 241).
-spec draw_planet(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), integer(), integer(), integer(), integer(), scene_fill(), integer(), integer(), integer(), integer()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
draw_planet(Pixels, Cx, Cy, Orbit_r, Dot_r, Fill, Pw, Ph, Frame, Period) ->
    {Px, Py} = orbit_position(Cx, Cy, Orbit_r, Frame, Period),
    draw_disc(Pixels, Px, Py, Dot_r, Fill, Pw, Ph, Frame, Period).

-file("src/etui/widgets/scene.gleam", 132).
-spec midpoint_loop(integer(), integer(), integer(), integer(), integer(), list({integer(), integer()})) -> list({integer(), integer()}).
midpoint_loop(Cx, Cy, Y, X, D, Acc) ->
    case Y > X of
        true ->
            Acc;

        false ->
            Pts = [{Cx + X, Cy + Y}, {Cx - X, Cy + Y}, {Cx + X, Cy - Y}, {Cx - X, Cy - Y}, {Cx + Y, Cy + X}, {Cx - Y, Cy + X}, {Cx + Y, Cy - X}, {Cx - Y, Cy - X}],
            Acc@1 = lists:append(Acc, Pts),
            Y@1 = Y + 1,
            {X@1, D@1} = case D < 0 of
                true ->
                    {X, (D + (2 * Y@1)) + 1};

                false ->
                    {X - 1, (D + (2 * (Y@1 - X))) + 1}
            end,
            midpoint_loop(Cx, Cy, Y@1, X@1, D@1, Acc@1)
    end.

-file("src/etui/widgets/scene.gleam", 125).
-spec circle_outline_pts(integer(), integer(), integer()) -> list({integer(), integer()}).
circle_outline_pts(Cx, Cy, R) ->
    case R =< 0 of
        true ->
            [{Cx, Cy}];

        false ->
            midpoint_loop(Cx, Cy, 0, R, 1 - R, [])
    end.

-file("src/etui/widgets/scene.gleam", 100).
-spec draw_circle_outline(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), integer(), integer(), integer(), scene_fill(), integer(), integer(), integer(), integer()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
draw_circle_outline(Pixels, Cx, Cy, R, Fill, Pw, Ph, Frame, Period) ->
    Pts = circle_outline_pts(Cx, Cy, R),
    N = erlang:length(Pts),
    gleam@list:index_fold(Pts, Pixels, fun(Px_dict, Pt, I) ->
        {Bx, By} = Pt,
        case (((Bx >= 0) andalso (By >= 0)) andalso (Bx < Pw)) andalso (By < Ph) of
            false ->
                Px_dict;

            true ->
                Fg = scene_color(Fill, I, N, Frame, Period),
                etui@braille:put(Px_dict, Bx, By, Fg)
        end
    end).

-file("src/etui/widgets/scene.gleam", 79).
-spec render_shape(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), shape(), integer(), integer(), integer()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
render_shape(Pixels, Shape, Pw, Ph, Frame) ->
    case Shape of
        {circle_outline, Cx, Cy, R, Fill} ->
            draw_circle_outline(Pixels, Cx, Cy, R, Fill, Pw, Ph, Frame, 60);

        {disc, Cx@1, Cy@1, R@1, Fill@1} ->
            draw_disc(Pixels, Cx@1, Cy@1, R@1, Fill@1, Pw, Ph, Frame, 60);

        {planet, Cx@2, Cy@2, Orbit_r, Dot_r, Fill@2, Period} ->
            draw_planet(Pixels, Cx@2, Cy@2, Orbit_r, Dot_r, Fill@2, Pw, Ph, Frame, Period);

        {mandelbrot, Max_iter} ->
            draw_mandelbrot(Pixels, Pw, Ph, Max_iter)
    end.

-file("src/etui/widgets/scene.gleam", 59).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), scene(), integer()) -> etui@buffer:buffer().
-doc(~" Render scene into `area`. `frame` drives animated shapes.").
render(Buf, Area, Scene, Frame) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Pw = erlang:element(2, erlang:element(3, Area)) * 2,
            Ph = erlang:element(3, erlang:element(3, Area)) * 4,
            Pixels = gleam@list:fold(erlang:element(2, Scene), etui@braille:new(), fun(Px_dict, Shape) ->
                render_shape(Px_dict, Shape, Pw, Ph, Frame)
            end),
            etui@braille:flush(Buf, Area, Pixels, erlang:element(3, Scene))
    end.

