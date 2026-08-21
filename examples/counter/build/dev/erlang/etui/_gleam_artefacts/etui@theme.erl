-module(etui@theme).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([normal/1, selection/1, accent_style/1, border_style/1, title_style/1, muted_style/1, error_style/1, warning_style/1, success_style/1, info_style/1, statusbar_style/1, dark/0, light/0, dracula/0, nord/0, catppuccin_mocha/0, catppuccin_latte/0, monokai/0, solarized_dark/0, gruvbox_dark/0, tokyo_night/0, with_accent/2, with_selection/3, with_statusbar/3, with_base/3]).
-export_type([theme/0]).

-type theme() :: {theme, etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color()}.

-file("src/etui/theme.gleam", 102).
-spec normal(theme()) -> etui@style:style().
-doc(~" Normal text: fg on bg.").
normal(T) ->
    etui@style:new(erlang:element(3, T), erlang:element(2, T), etui@style:none()).

-file("src/etui/theme.gleam", 107).
-spec selection(theme()) -> etui@style:style().
-doc(~" Selected item: selection_fg on selection_bg.").
selection(T) ->
    etui@style:new(erlang:element(7, T), erlang:element(6, T), etui@style:none()).

-file("src/etui/theme.gleam", 112).
-spec accent_style(theme()) -> etui@style:style().
-doc(~" Accent text: accent on bg.").
accent_style(T) ->
    etui@style:new(erlang:element(8, T), erlang:element(2, T), etui@style:none()).

-file("src/etui/theme.gleam", 117).
-spec border_style(theme()) -> etui@style:style().
-doc(~" Border color: border on bg.").
border_style(T) ->
    etui@style:new(erlang:element(4, T), erlang:element(2, T), etui@style:none()).

-file("src/etui/theme.gleam", 122).
-spec title_style(theme()) -> etui@style:style().
-doc(~" Title color: title on bg.").
title_style(T) ->
    etui@style:new(erlang:element(5, T), erlang:element(2, T), etui@style:none()).

-file("src/etui/theme.gleam", 127).
-spec muted_style(theme()) -> etui@style:style().
-doc(~" Muted/secondary text: muted on bg.").
muted_style(T) ->
    etui@style:new(erlang:element(9, T), erlang:element(2, T), etui@style:none()).

-file("src/etui/theme.gleam", 132).
-spec error_style(theme()) -> etui@style:style().
-doc(~" Error text: error color on bg, bold.").
error_style(T) ->
    etui@style:new(erlang:element(10, T), erlang:element(2, T), etui@style:bold()).

-file("src/etui/theme.gleam", 137).
-spec warning_style(theme()) -> etui@style:style().
-doc(~" Warning text: warning color on bg.").
warning_style(T) ->
    etui@style:new(erlang:element(11, T), erlang:element(2, T), etui@style:none()).

-file("src/etui/theme.gleam", 142).
-spec success_style(theme()) -> etui@style:style().
-doc(~" Success text: success color on bg.").
success_style(T) ->
    etui@style:new(erlang:element(12, T), erlang:element(2, T), etui@style:none()).

-file("src/etui/theme.gleam", 147).
-spec info_style(theme()) -> etui@style:style().
-doc(~" Info text: info color on bg.").
info_style(T) ->
    etui@style:new(erlang:element(13, T), erlang:element(2, T), etui@style:none()).

-file("src/etui/theme.gleam", 152).
-spec statusbar_style(theme()) -> etui@style:style().
-doc(~" Status bar: statusbar_fg on statusbar_bg.").
statusbar_style(T) ->
    etui@style:new(erlang:element(15, T), erlang:element(14, T), etui@style:none()).

-file("src/etui/theme.gleam", 161).
-spec dark() -> theme().
-doc(~" Generic dark theme using ANSI 16-color palette.
 Works on every terminal, even without true-color support.").
dark() ->
    {theme, default, default, {indexed, 8}, {indexed, 15}, {indexed, 4}, {indexed, 15}, {indexed, 12}, {indexed, 8}, {indexed, 9}, {indexed, 11}, {indexed, 10}, {indexed, 14}, {indexed, 0}, {indexed, 15}}.

-file("src/etui/theme.gleam", 181).
-spec light() -> theme().
-doc(~" Generic light theme using ANSI 16-color palette.").
light() ->
    {theme, default, default, {indexed, 7}, {indexed, 0}, {indexed, 12}, {indexed, 15}, {indexed, 4}, {indexed, 7}, {indexed, 1}, {indexed, 3}, {indexed, 2}, {indexed, 6}, {indexed, 7}, {indexed, 0}}.

-file("src/etui/theme.gleam", 202).
-spec dracula() -> theme().
-doc(~" Dracula, dark purple palette.
 Original palette: https://draculatheme.com").
dracula() ->
    {theme, {rgb, 40, 42, 54}, {rgb, 248, 248, 242}, {rgb, 98, 114, 164}, {rgb, 139, 233, 253}, {rgb, 68, 71, 90}, {rgb, 248, 248, 242}, {rgb, 189, 147, 249}, {rgb, 98, 114, 164}, {rgb, 255, 85, 85}, {rgb, 255, 184, 108}, {rgb, 80, 250, 123}, {rgb, 139, 233, 253}, {rgb, 33, 34, 44}, {rgb, 248, 248, 242}}.

-file("src/etui/theme.gleam", 223).
-spec nord() -> theme().
-doc(~" Nord, arctic, north-bluish dark palette.
 Original palette: https://www.nordtheme.com").
nord() ->
    {theme, {rgb, 46, 52, 64}, {rgb, 216, 222, 233}, {rgb, 76, 86, 106}, {rgb, 136, 192, 208}, {rgb, 67, 76, 94}, {rgb, 236, 239, 244}, {rgb, 129, 161, 193}, {rgb, 76, 86, 106}, {rgb, 191, 97, 106}, {rgb, 235, 203, 139}, {rgb, 163, 190, 140}, {rgb, 143, 188, 187}, {rgb, 36, 41, 51}, {rgb, 216, 222, 233}}.

-file("src/etui/theme.gleam", 244).
-spec catppuccin_mocha() -> theme().
-doc(~" Catppuccin Mocha, warm pastel dark palette.
 Original palette: https://catppuccin.com").
catppuccin_mocha() ->
    {theme, {rgb, 30, 30, 46}, {rgb, 205, 214, 244}, {rgb, 88, 91, 112}, {rgb, 166, 227, 161}, {rgb, 69, 71, 90}, {rgb, 205, 214, 244}, {rgb, 137, 180, 250}, {rgb, 108, 112, 134}, {rgb, 243, 139, 168}, {rgb, 249, 226, 175}, {rgb, 166, 227, 161}, {rgb, 137, 220, 235}, {rgb, 24, 24, 37}, {rgb, 205, 214, 244}}.

-file("src/etui/theme.gleam", 265).
-spec catppuccin_latte() -> theme().
-doc(~" Catppuccin Latte, warm pastel light palette.
 Original palette: https://catppuccin.com").
catppuccin_latte() ->
    {theme, {rgb, 239, 241, 245}, {rgb, 76, 79, 105}, {rgb, 172, 176, 190}, {rgb, 64, 160, 43}, {rgb, 188, 192, 204}, {rgb, 76, 79, 105}, {rgb, 30, 102, 245}, {rgb, 172, 176, 190}, {rgb, 210, 15, 57}, {rgb, 223, 142, 29}, {rgb, 64, 160, 43}, {rgb, 4, 165, 229}, {rgb, 204, 208, 218}, {rgb, 76, 79, 105}}.

-file("src/etui/theme.gleam", 286).
-spec monokai() -> theme().
-doc(~" Monokai, vibrant dark palette.
 Inspired by the Monokai color scheme.").
monokai() ->
    {theme, {rgb, 39, 40, 34}, {rgb, 248, 248, 242}, {rgb, 117, 113, 94}, {rgb, 166, 226, 46}, {rgb, 73, 72, 62}, {rgb, 248, 248, 242}, {rgb, 102, 217, 239}, {rgb, 117, 113, 94}, {rgb, 249, 38, 114}, {rgb, 253, 151, 31}, {rgb, 166, 226, 46}, {rgb, 102, 217, 239}, {rgb, 30, 30, 27}, {rgb, 248, 248, 242}}.

-file("src/etui/theme.gleam", 307).
-spec solarized_dark() -> theme().
-doc(~" Solarized Dark, precision dark palette.
 Original palette by Ethan Schoonover.").
solarized_dark() ->
    {theme, {rgb, 0, 43, 54}, {rgb, 131, 148, 150}, {rgb, 88, 110, 117}, {rgb, 38, 139, 210}, {rgb, 7, 54, 66}, {rgb, 147, 161, 161}, {rgb, 38, 139, 210}, {rgb, 88, 110, 117}, {rgb, 220, 50, 47}, {rgb, 181, 137, 0}, {rgb, 133, 153, 0}, {rgb, 42, 161, 152}, {rgb, 0, 26, 33}, {rgb, 131, 148, 150}}.

-file("src/etui/theme.gleam", 328).
-spec gruvbox_dark() -> theme().
-doc(~" Gruvbox Dark, retro groove dark palette.
 Inspired by the Gruvbox color scheme.").
gruvbox_dark() ->
    {theme, {rgb, 29, 32, 33}, {rgb, 235, 219, 178}, {rgb, 80, 73, 69}, {rgb, 184, 187, 38}, {rgb, 60, 56, 54}, {rgb, 235, 219, 178}, {rgb, 215, 153, 33}, {rgb, 102, 92, 84}, {rgb, 251, 73, 52}, {rgb, 250, 189, 47}, {rgb, 184, 187, 38}, {rgb, 131, 165, 152}, {rgb, 20, 22, 23}, {rgb, 235, 219, 178}}.

-file("src/etui/theme.gleam", 349).
-spec tokyo_night() -> theme().
-doc(~" Tokyo Night, dark cool-blue palette.
 Inspired by the Tokyo Night color scheme.").
tokyo_night() ->
    {theme, {rgb, 26, 27, 38}, {rgb, 169, 177, 214}, {rgb, 65, 72, 104}, {rgb, 122, 162, 247}, {rgb, 41, 46, 66}, {rgb, 192, 202, 245}, {rgb, 187, 154, 247}, {rgb, 86, 95, 137}, {rgb, 247, 118, 142}, {rgb, 224, 175, 104}, {rgb, 158, 206, 106}, {rgb, 125, 207, 255}, {rgb, 22, 22, 30}, {rgb, 169, 177, 214}}.

-file("src/etui/theme.gleam", 378).
-spec with_accent(theme(), etui@style:color()) -> theme().
-doc(~" Override individual fields on an existing theme.
 Use Gleam's record update syntax directly:
 ```gleam
 let my = Theme(..theme.nord(), accent: style.Rgb(255, 165, 0))
 ```
 These helpers cover common single-field tweaks.
 Replace the accent color.").
with_accent(T, Color) ->
    {theme, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), erlang:element(5, T), erlang:element(6, T), erlang:element(7, T), Color, erlang:element(9, T), erlang:element(10, T), erlang:element(11, T), erlang:element(12, T), erlang:element(13, T), erlang:element(14, T), erlang:element(15, T)}.

-file("src/etui/theme.gleam", 383).
-spec with_selection(theme(), etui@style:color(), etui@style:color()) -> theme().
-doc(~" Replace the selection colors.").
with_selection(T, Bg, Fg) ->
    {theme, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), erlang:element(5, T), Bg, Fg, erlang:element(8, T), erlang:element(9, T), erlang:element(10, T), erlang:element(11, T), erlang:element(12, T), erlang:element(13, T), erlang:element(14, T), erlang:element(15, T)}.

-file("src/etui/theme.gleam", 388).
-spec with_statusbar(theme(), etui@style:color(), etui@style:color()) -> theme().
-doc(~" Replace the status bar colors.").
with_statusbar(T, Bg, Fg) ->
    {theme, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), erlang:element(5, T), erlang:element(6, T), erlang:element(7, T), erlang:element(8, T), erlang:element(9, T), erlang:element(10, T), erlang:element(11, T), erlang:element(12, T), erlang:element(13, T), Bg, Fg}.

-file("src/etui/theme.gleam", 393).
-spec with_base(theme(), etui@style:color(), etui@style:color()) -> theme().
-doc(~" Replace main bg/fg.").
with_base(T, Bg, Fg) ->
    {theme, Bg, Fg, erlang:element(4, T), erlang:element(5, T), erlang:element(6, T), erlang:element(7, T), erlang:element(8, T), erlang:element(9, T), erlang:element(10, T), erlang:element(11, T), erlang:element(12, T), erlang:element(13, T), erlang:element(14, T), erlang:element(15, T)}.

