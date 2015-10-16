# A* Search Algorithm Demo

This is a small interactive demo of the A* search algorithm.

I hope it may be useful for anyone either learning A* search
or looking for code to copy/paste or port into their app.

![](https://github.com/tylerneylon/a_star_search_demo/blob/master/screenshot.png)

## To run

You'll need the [löve game engine](https://love2d.org/) in order to run this code.
The instructions below are for mac users; for windows or linux, I believe double-clicking on the
`demo.love` file in your gui will work.

    $ git clone https://github.com/tylerneylon/a_star_search_demo.git
    $ cd a_star_search_demo
    $ open demo.love

## To use

There are 2 path-drawing modes, and a maze-editing mode. Switch
modes using the 3 top-left buttons.

### Path-drawing modes

Click any grid square to see the found shortest path from your mouse click to the
goal circle in the upper-right grid square.

### Maze-editing modes

Click on any grid square to toggle it between being a wall or open space.

## To permanently edit the default maze.

The default maze is saved in the human-friendly file `maze.data`.

Right now the "save maze" button works *only when run from a shell*.
That is, when you start the app by running `love .` in the repo's directory;
as a prerequisite, you'd have to have created a symlink from your `PATH` directly
to the core Löve binary within the main Löve app bundle so the `love` command
makes sense to your shell.
The save button is fragile like this because, when your app is run from a
`.love` file, Löve is actually running things from a temporary directory
behind the scenes and interferes with Lua's default file access setup.

You do have the option of editing `maze.data` and then recreating `demo.love`
like this:

    $ zip demo.love main.lua maze.data

If you use that method, you can effectively change the maze and interact with
it via the default start-Löve-from-the-gui method (or by running `open demo.love` from a shell
  on a mac).

## About the shortcut algorithm

This algorithm starts with the output of an A* search and then
improves on it by finding straight-line segments that may be diagonal
but are not interrupted by a wall. Internally, it uses a 2d ray-marching
sub-algorithm to determine when a candidate diagonal hits a wall.

Intuitively, suppose we're considering the shortcut indicated by the
blue line below.

![](https://raw.githubusercontent.com/tylerneylon/a_star_search_demo/master/short_cut_search.png)

The ray-marching subalgorithm will locate each of the points `p1`, `p2`, `p3`, etc. until
it reaches the destination. Along the way it will check each potential wall for existence.
In the picture above, potential walls are indicated by black lines.

If no walls are encountered, the shortcut is taken.

As far as I know, this improvement is independent and original. However, I haven't done
any research on it, so maybe it is already well-known. It is also not guaranteed to
find all possible shortcuts, as it takes them greedily and will sometimes miss an opportunity
because of that.

## A note on the A* search algorithm here

As a side note, it is possible to implement A* more efficiently by using a data
structure called a heap to more efficiently find the value of `best_pt` during
each iteration of the main loop in `find_path`. The current code will take
linear time to find `best_pt`, whereas it could theoretically take log(n) time
instead. In practice, for small-ish grids or paths, the added simplicity of the
current code may actually be faster in many specific cases, though.

## Learning from or using this code

I'd be happy if anyone uses this code either directly or indirectly via porting
to your favorite language. I hope this code may also be useful for anyone
interested in learning about A* search.

Other great A* search pages:

* The [red blob games post on A*](http://www.redblobgames.com/pathfinding/a-star/introduction.html)
* The [wikipedia page on A*](https://en.wikipedia.org/wiki/A*_search_algorithm)
