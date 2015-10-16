# A* Search Algorithm Demo

This is a small interactive demo of the A* search algorithm.

![](https://github.com/tylerneylon/a_star_search_demo/blob/master/a_star_screenshot.png)

You can edit the human-friendly text file `maze.data` to create a custom maze,
which will be visualized as in the screenshot above. In the file, space
characters represent open space and `*` characters are walls. The code assumes
that every line is of equal length, which means padding the end of each line
with space characters for lines not ending in a wall.

The interaction is simple: mouse click anywhere there's not a wall, and the code
will quickly find a shortest path for you and draw it. The destination/goal
point is always in the upper-right corner of the maze.

The actual algorithm is in the function `find_path` in `main.lua`.
Even if you don't know Lua, it's an easy-to-read language, and I imagine it
would be easy to port this code into your favorite language.

As a side note, it is possible to implement A* more efficiently by using a data
structure called a heap to more efficiently find the value of `best_pt` during
each iteration of the main loop in `find_path`. The current code will take
linear time to find `best_pt`, whereas it could theoretically take log(n) time
instead. In practice, for small-ish grids or paths, the added simplicity of the
current code may actually be faster in many specific cases, though.


