# Alternative graphics device for `RStudio`

Replaces the default `RStudio` graphics device with a light-weight
`shiny` application that renders plots as `SVG` images in the viewer
pane. This is useful when the built-in device is unavailable or
misbehaves, for example on remote or containerized `RStudio` servers.

`pv_init` starts the viewer and installs the hooks, `pv_off` removes
them and shuts the viewer down, `pv_show` sends the current plot to the
viewer manually, and `pv_dims` reports the viewer size in pixels.

`pv_off` also closes the off-screen devices that `pv_init` opened. Since
[`graphics::par()`](https://rdrr.io/r/graphics/par.html) settings belong
to a device, this resets them: the next plot starts on a fresh device
with the defaults. Devices opened by anything else are left untouched.

## Usage

``` r
pv_init(...)

pv_off(...)

pv_show(...)

pv_dims(...)
```

## Arguments

- ...:

  passed to the internal handlers; `pv_init` accepts `hooks`, a
  character vector of new-page hook names to watch, and `watch`, see
  'Details'

## Value

`pv_init`, `pv_off`, and `pv_show` invisibly return a logical value
indicating whether the corresponding action succeeded. `pv_dims` returns
an integer vector of length two: the viewer width and height in pixels,
defaulting to `c(1000L, 700L)` when the viewer has not reported its
size.

## Details

`pv_init` only takes effect in interactive `RStudio` sessions, and
requires the packages `svglite`, `rstudioapi`, `callr`, `httpuv`, and
`shiny` to be installed; otherwise the call is a no-op. When enabled,
the graphics device option is redirected to an off-screen `pdf` device
with the display list enabled, a top-level task callback named
`tools:plotview` re-renders the recorded plot whenever a new page is
drawn, and helper functions (`.pv_show`, `.pv_dims`, `.pv_start`,
`.pv_stop`) are attached to the search path under `tools:plotview`.

Incremental drawing such as
[`points()`](https://rdrr.io/r/graphics/points.html),
[`lines()`](https://rdrr.io/r/graphics/lines.html), or
[`legend()`](https://rdrr.io/r/graphics/legend.html) runs no hook, so
the hooks alone would miss it. Instead the callback compares the length
of the device display list with the length at the last render, and
re-renders when it differs; the `plot.new` hook still covers the case of
a new page that happens to have the same length. This means the display
list is recorded once per top-level command, which is the cost of the
feature; pass `watch = FALSE` to `pv_init` to disable it and fall back
to the hooks alone.

While a `shiny` application is running in the current session (that is,
[`shiny::isRunning()`](https://rdrr.io/pkg/shiny/man/isRunning.html) is
`TRUE` or a reactive domain is active), the hooks step aside: new
devices are opened with the original device and plots are not captured,
so `shiny` renders as usual. Normal behavior resumes once the
application stops. The viewer's own application does not count, as it
runs in a separate process.

The viewer runs in a background R process and reports its own width and
height back to the main session, so plots are re-drawn at the size of
the viewer pane. Only the 20 most recent pages are kept on disk.

The history holds one entry per page:
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) and friends
start a new one, while incremental drawing, a refresh, and a resize
re-render the current entry in place instead of appending a copy of it.
Three buttons in the top-right corner of the viewer navigate that
history: previous steps back one page (and does nothing at the oldest
one still on disk), next steps forward one page, and the last button
jumps to the newest page. Stepping forward from the newest image, or
pressing the last button, also asks the main session to re-render the
current plot, the same as calling `pv_show()`. Such a request is passed
back through the viewer configuration file, which the main session polls
once per second using
[`later::later`](https://later.r-lib.org/reference/later.html) while
registered; resizing the viewer is picked up the same way. The polling
stops on `pv_off()`.

## Examples

``` r
if (FALSE) { # \dontrun{

# Start the alternative graphics device
ravemanager::pv_init()

plot(1:10)

# Query the viewer size
ravemanager::pv_dims()

# Re-send the current plot, e.g. after resizing the viewer
ravemanager::pv_show()

# Restore the default device
ravemanager::pv_off()

} # }
```
