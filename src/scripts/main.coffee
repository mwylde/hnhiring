slinky_require("jquery-1.7.js")
slinky_require("underscore.js")

App =
  threads: {}

  show_modal: (content) ->
    App.hide_modal()
    $("#modal").html content
    $("#scrim").addClass("modal-background")
    $("#scrim").click App.hide_modal
    $(".close-dialog").click () -> App.hide_modal(); false
    $("body").css("overflow", "hidden")

  hide_modal: () ->
    $("#modal").empty()
    $("#scrim").removeClass("modal-background")
    $("body").css("overflow", "inherit")

get_threads = (cb) ->
  $.ajax url: "/data//threads.json", success: cb, dataType: 'json'

class MainView
  scrolling: false
  counter: 0
  current: $("")

  constructor: () ->
    @el = $("#content")
    # Set up keyboard shortcuts
    $(document).keydown (data) =>
      switch data.which
        when 74,32 # J, space
          if !@scrolling
            @set_current(@get_next(), true)
          else
            @counter++
        when 75 # K
          if !@scrolling
            @set_current(@get_prev(), true)
          else
            @counter--
        when 72 # H
          @hide(@get_current())
        when 70 # F
          $("input[name='filter']").focus()
          false
        when 47 # ?
          @show_help()

    $("#content").scroll (() => @handle_scroll())

  load_thread: (id) ->
    @id = id
    $(".thread-link").parent().removeClass "selected"
    $("##{id}").parent().addClass "selected"
    localStorage.setItem("selected_thread", id)
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
              <div class="hide">
                <a href="javascript:">&ndash;</a>
              </div>
            </div>
            <div class="body">#{c.html}</div></li>
          """
        )
      $("#content ul").html cs.value().join("\n")
      @filter()
      cid = localStorage.getItem("selected_comment:#{@id}")
      el = $("##{cid}", @el)
      @set_current((if el.size() > 0 then el else $("li.comment", @el).first()), yes)

      $("li.comment", @el).click (e) =>
        @set_current(e.currentTarget, yes)

    $("ul", @el).html '<div class="loading"><img src="/loading.gif" /></div>'
    $("li.selected", @el).removeClass("selected")
    $("li:has(##{@id})", @el).addClass("selected")

    if App.threads[@id]
      cb(App.threads[@id])
    else
      $.ajax url: "/data/comments-#{@id}.json", success: cb, dataType: 'json'

  show_help: () ->
    keys = [
      ["J", "Scroll to the next post"],
      ["K", "Scroll to the previous post"],
      ["H", "Hide or show the current post"],
      ["F", "Focus the filter field"],
      ["&#9166;", "Blur the filter field"],
      ["?", "Shows this help"]
    ]
    ul = _(keys).map ([key, desc]) ->
      """
        <li>
          <div class="key">#{key}</div>
          <div class="command">#{desc}</div>
        </li>
      """

    App.show_modal("""
      <div id="keyboard-shortcuts" class="modal-dialog">
        <a href="javascript:" class="close-dialog"><img src="close.gif" /></a>
        <h3 class="title">keyboard shortcuts</h3>
        <ul>#{ul.join("\n")}</ul>
      </div>
    """)

  handle_scroll: () ->
    # Require 100px of scrolling before we override the current
    if !@scrolling and Math.abs($(@el).scrollTop() - @set_at) > 100
      @set_current _($("li.comment")).find((el) ->
        $(el).position().top + $(el).height()/2 > 0)

  set_current: (el, scroll = false) ->
    @current = $(el)
    @set_at = $(@el).scrollTop()
    $("li.comment").removeClass("current")
    @current.addClass("current")
    if scroll
      @scroll_to(@current)
    localStorage.setItem("selected_comment:#{@id}", @current.attr('id'))

  get_current: () -> @current
  get_next: (i = 0) ->
    el = $(@current.nextAll(":visible")[i])
    if el.size() != 0 then el else @current
  get_prev: (i = 0) ->
    el = $(@current.prevAll(":visible")[i])
    if el.size() != 0 then el else @current

  scroll_to: (el) ->
    if el and $(el).offset()
      top = $("#content").scrollTop() + $(el).offset().top - 140 #45
      @set_at = top
      @scrolling = yes
      $("#content").animate({scrollTop: top},
        complete: () =>
          @scrolling = no
          if @counter > 0
            @set_current(@get_next(@counter), yes)
          else if @counter < 0
            @set_current(@get_prev(-@counter), yes)
          @counter = 0
      )

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
    if @current.css("display") == "none"
      @set_current @get_next()

$(document).ready () ->
  main_view = new MainView()
  App.main_view = main_view
  main_view.show_help()
  get_threads (data) ->
    threads = _(data).map((d) ->
      "<li><a class=\"thread-link\" href=\"javascript:\" id=\"#{d[1]}\">#{d[0]}</a></li>")
    $("#sidebar ul").html threads.join("\n")
    $("a.thread-link").on "click", (e) ->
      el = e.srcElement or e.target
      main_view.load_thread el.id

    id = localStorage.getItem("selected_thread") or data[1][1]
    main_view.load_thread id

  $(".filter input").keyup (e) ->
    if e.keyCode == 13 # Enter key
      $(".filter input").blur()
    else
      main_view.filter()
  $(".filter input").click () ->
    # We have to catch the case that the "x" button was clicked
    if $(".filter input").val() == ""
      main_view.filter()

window.App = App