asyncfinder.vim
===============

asyncfinder.vim - simple asynchronous fuzzy file finder for vim that won't make you wait 
for results evar! EVAR! It uses python's threading module and does pattern matching in
background thread so your vim won't get stuck and you won't get frustuated by waiting for 
results. It's quite similar to [FuzzyFinder], [ku], [ctrlp.vim] and [unite.vim] and inspired by those
plugins but is much more simple in its functionality.

screenshot
----------
![image](http://i.imgur.com/6lBlh.png)

usage
-----

    :AsyncFinder

[FuzzyFinder]: https://bitbucket.org/ns9tks/vim-fuzzyfinder/
[ku]: https://github.com/kana/vim-ku
[ctrlp.vim]: https://github.com/kien/ctrlp.vim
[unite.vim]: https://github.com/Shougo/unite.vim
