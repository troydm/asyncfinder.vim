asyncfinder.vim
===============

asyncfinder.vim - simple asynchronous fuzzy file finder and search text for vim that won't make you wait 
for results evar! EVAR! It uses python's threading module and does pattern matching in
background thread so your vim won't get stuck and you won't get frustuated by waiting for 
results. It's quite similar to [FuzzyFinder], [ctrlp.vim] and [unite.vim] and inspired by those
plugins but is much more simple in its functionality. It supports matching most recently used files
too but you need to have [MRU] plugin to use this functionality. For searching text it supports 
grep, ack, ag commands and also has a builtin search functionality that can be used in enviroments where 
those commands aren't available

screenshot
----------
![image](http://i.imgur.com/6lBlh.png)

usage
-----

    :AsyncFinder - search for filename
    :AsyncGrep - search for pattern in files recursively

[FuzzyFinder]: https://bitbucket.org/ns9tks/vim-fuzzyfinder/
[ctrlp.vim]: https://github.com/kien/ctrlp.vim
[unite.vim]: https://github.com/Shougo/unite.vim
[MRU]: http://www.vim.org/scripts/script.php?script_id=521
