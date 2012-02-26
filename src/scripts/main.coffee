slinky_require("jquery-1.7.js")
slinky_require("underscore.js")

App =
  threads: {}

get_threads = (cb) ->
  $.ajax url: "/data//threads.json", success: cb, dataType: 'json'

select_thread = (id) ->

class MainView
  scrolling: false

  constructor: () ->
    @el = $("#content")
    # Set up keyboard shortcuts
    $(document).keydown (data) =>
      switch data.which
        when 74,32 # J, space
          @set_current(@get_next(), true)
        when 75 # K
          @set_current(@get_prev(), true)
        when 72 # H
          @hide(@get_current())

      $("#content").scroll (() => @handle_scroll())
      @set_current $("li.comment", @el).first()

  load_thread: (id) ->
    @id = id
    @render()

  render: () ->
    cb = (comments) =>
      App.threads[@id] = comments
      cs = _(comments).chain()
        .sortBy((c) -> c.time)
        .filter((c) -> c.level == 0)
        .map((c) ->
          hidden = if localStorage.getItem("c#{c.id}:hidden") == "true" then "hidden" else ""
          """
            <li id="c#{c.id}" class="comment #{hidden}">
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
      @filter()
      @set_current($("li.comment", @el).first())

    $("ul", @el).html '<div class="loading"><img src="/loading.gif" /></div>'
    $("li.selected", @el).removeClass("selected")
    $("li:has(##{@id})", @el).addClass("selected")

    if App.threads[@id]
      cb(App.threads[@id])
    else
      $.ajax url: "/data/comments-#{@id}.json", success: cb, dataType: 'json'

  handle_scroll: () ->
    if !@scrolling
      @set_current _($("li.comment")).find((el) -> $(el).position().top > 100)

  set_current: (el, scroll) ->
    @current = $(el)
    $("li.comment").removeClass("current")
    @current.addClass("current")
    if scroll
      @scroll_to(@current)

  get_current: () -> @current
  get_next: () -> @current.next()
  get_prev: () -> @current.prev()

  scroll_to: (el) ->
    if el and $(el).offset()
      top = $("#content").scrollTop() + $(el).offset().top - 140 #45
      @scrolling = yes
      $("#content").animate({scrollTop: top}, {complete: () => @scrolling = no})

  hide: (el) ->
    w = $(el)
    localStorage.setItem(w.attr('id')+":hidden", !w.hasClass("hidden"))
    w.toggleClass("hidden")

  filter: () ->
    r = new RegExp($(".filter input").val(), "gi")
    $("li.comment").each (i, el) ->
      text = $(".body", el).html()
      if r.test(text)
        $(el).show()
      else
        $(el).hide()

$(document).ready () ->
  main_view = new MainView()
  get_threads (data) ->
    threads = _(data).map((d) ->
      "<li><a class=\"thread-link\" href=\"javascript:\" id=\"#{d[1]}\">#{d[0]}</a></li>")
    $("#sidebar ul").html threads.join("\n")
    $("a.thread-link").on "click", (e) ->
      el = e.srcElement or e.target
      main_view.load_thread el.id

    main_view.load_thread data[1][1]

  $(".filter input").keyup () ->
    main_view.filter()
  $(".filter input").click () ->
    # We have to catch the case that the "x" button was clicked
    if $(".filter input").val() == ""
      main_view.filter()

window.App = App