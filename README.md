# Neovim function/method and class motions

Adds `[y/d/v][i/a][f/c]` motions corresponding to `[yank/delete/visual][inside/a][function/class]`.

Examples:
* yif - yank inside function/method
* daf - delete a function/method
* vic - visual select inside of class

Uses TreeSitter to select text semantically and tested with dart and lua until I was happy.

## License

Copyright (c) Olafur Palsson.  Distributed under the same terms as Neovim itself.
See `:help license`.
