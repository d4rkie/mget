mget
====

This script is designed to leech manga from mangastream.net - it supports both their legacy and the new reader (assembles back the split pages). Use it for personal purposes only, or as a study *(this is my first attempt at ruby)*. 
the script is made executable, so for convenience symlink it to a /bin visible from PATH

prerequisites
-------------
* nokogiri
* css_parser
* fileutils

usage
-----

* **mget** - list all available chapters and their links
* **mget {mangastream-link}** - downloads the chapter this page is from to a folder named: {series-name}{chapter-number}
* **mget list** - does the same as **mget**
* **mget last {number_of_chapters}** - downloads latest {numbre_of_chapters} from the **mget list**
* **mget all** - downloads all the chapters returned by **mget list** 

