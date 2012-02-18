slinky_require("jquery-1.7.js")
slinky_require("underscore.js")

App =
  threads: {}

get_threads = (cb) ->
  $.ajax url: "/data//threads.json", success: cb, dataType: 'json'

select_thread = (id) ->
  cb = (comments) ->
    App.threads[id] = comments
    cs = _(comments).chain().filter((c) -> c.level == 0).map((c) ->
      "<li class=\"comment\">
        <div class=\"top\">
          <div class=\"posted-by\">
            <a href=\"http://news.ycombinator.com/user?id=#{c.submitter}\">#{c.submitter}</a>
          </div>
          <div class=\"link\">
            <a href=\"#{c.url}\">link</a>
          </div>
        </div>
        <div class=\"body\">#{c.html}</div></li>"
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