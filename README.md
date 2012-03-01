# Who is hiring?

Good question. Fortunately, [Hacker News](http://news.ycombinator.com)
has the answer each month in the form of hiring posts where employers
can post open positions and freelancers can advertise their skills.
This is a wonderful service and many people have reported success on
both sides of the hiring process.

But, let's face it, HN is not the best format for browsing job
listings. [HNHiring.me](http://hnhiring.me) aims at providing a better
experience for job searchers, making it easier to take advantage of
these posts.

Amongst the features:

* A year's worth of posts
* Date-based ordering (focus on the newest jobs)
* Instant filtering by regular expression (find jobs in New York|NYC)
* Ability to hide uninteresting posts
* Helpful keyboard shortcuts (never touch the mouse)

## About the code

The code is split into two pieces. The site itself is completely
static, which is helpful when Hacker News is sending hundreds of
simultaneous users to my small VPS. It's written in
CoffeeScript, backed by jQuery and Underscore.js. On page load it
requests a JSON file containing the list of job threads, which is used to
populate the side bar. Then, for each selected thread, a JSON file
containing the comment data is requested via AJAX.

The second piece is a small Ruby script that generates those JSON
files. Found in `get_data.rb`, it uses nokogiri to parse Hacker News'
HTML. It can be run on the command line as so:

```
$ ruby get_data.rb output_dir/
```

and the relevant JSON files will be generated and output into
`output_dir/`.

Note that this script requires a running Redis instance. Why? Because
unfortunately there is no way to get the timestamp for a HN post. However,
we do have relative times (e.g., "posted 5 minutes ago"). While these
are fairly precise within an hour of posting, they quickly become
useless&mdash;the next day, nearly every comment has "posted 1 day ago".
So by running `get_data.rb` at least once an hour, we can get
timestamps which are accurate to the minute. But the next time we run
it we want to maintain the more accurate times, not replace them with
new, less accurate ones. Therefore we store the time of each post in
Redis, so that when we re-run the script we can check if we already
have a better estimate.

## Building the site

In order to build the site, you will need
[Slinky](https://github.com/mwylde/slinky), my static site builder.
Once that's installed (perhaps via `gem install slinky`) you can
generate the output code by running `./build.sh` in the main
directory.
