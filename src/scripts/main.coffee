slinky_require("jquery-1.7.js")
slinky_require("underscore.js")

App =
  threads: {}

get_threads = (cb) ->
  $.ajax url: "/data//threads.json", success: cb, dataType: 'json'

select_thread = (id) ->
  cb = (comments) ->
    App.threads[id] = comments
    cs = _(comments).chain()
      .sortBy((c) -> c.time)
      .filter((c) -> c.level == 0)
      .map((c) ->
        """
          <li class="comment">
          <div class="top">
            <div class="posted-by">
              <a href="http://news.ycombinator.com/user?id=#{c.submitter}">#{c.submitter}</a>
            </div>
            <div class="link">
              <a href="#{c.url}">link</a>
            </div>
          </div>
          <div class="body">#{c.html}</div></li>
        """
      )
    $("#content ul").html cs.value().join("\n")
    filter()

  $("#content ul").html '<div class="loading"><img src="/loading.gif" /></div>'
  $("li.selected").removeClass("selected")
  $("li:has(##{id})").addClass("selected")

  if App.threads[id]
    cb(App.threads[id])
  else
    $.ajax url: "/data/comments-#{id}.json", success: cb, dataType: 'json'

current_thread = () ->
  $(next_thread()).prev()

on_scroll = () ->
  $("li.comment").removeClass("current")
  $(current_thread()).addClass("current")

next_thread = () ->
  _($("li.comment")).find((el) -> $(el).position().top > 40)

previous_thread = () ->
  $(current_thread()).prev()

scroll_to = (el) ->
  if el and $(el).offset()
    top = $("#content").scrollTop() + $(el).offset().top - 45
    $("#content").animate({scrollTop: top})
    window.scrollTo(0.6)

hide = (el) ->
  $(el).toggleClass("hidden")

filter = () ->
  r = new RegExp($(".filter input").val(), "gi")
  $("li.comment").each (i, el) ->
    text = $(".body", el).html()
    if r.test(text)
      $(el).show()
    else
      $(el).hide()

$(document).ready () ->
  get_threads (data) ->
    threads = _(data).map((d) ->
      "<li><a class=\"thread-link\" href=\"javascript:\" id=\"#{d[1]}\">#{d[0]}</a></li>")
    $("#sidebar ul").html threads.join("\n")
    $("a.thread-link").on "click", (e) ->
      el = e.srcElement or e.target
      select_thread(el.id)

    select_thread(data[0][1])

  $(".filter input").keyup () ->
    filter()
  $(".filter input").click () ->
    # We have to catch the case that the "x" button was clicked
    if $(".filter input").val() == ""
      filter()

  # Set up keyboard shortcuts
  $(document).keydown (data) ->
    switch data.which
      when 74,32 # J, space
        scroll_to(next_thread())
      when 75 # K
        scroll_to(previous_thread())
      when 72 # H
        hide(current_thread())

  $("#content").scroll (() -> on_scroll())
  on_scroll()
window.App = App