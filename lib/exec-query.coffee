{CompositeDisposable} = require 'atom'

class ExecQuery
  constructor: ->
    @results = []; @resId = 0
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.config.observe 'connect-kdb-q.showWidth', (@showWidth) =>
    @subscriptions.add atom.config.observe 'connect-kdb-q.showHeight', (@showHeight) =>
    @subscriptions.add atom.config.observe 'connect-kdb-q.maxFullResults', (@maxFullResults) =>
    @subscriptions.add atom.config.observe 'connect-kdb-q.maxResults', (@maxResults) =>
    @subscriptions.add atom.config.observe 'connect-kdb-q.QueryResultsPosition', (@panePosition) =>
    @subscriptions.add atom.config.observe 'connect-kdb-q.ResultFontSize', (@fontSize) =>
      return unless @resultView
      view = atom.views.getView @resultView.getEditor()
      view.style.fontSize = @fontSize + 'px'

  init: (@servers) ->

  execLine: ->
    return unless editor = @getEditor()
    pos = editor.getCursorBufferPosition()
    line = editor.lineTextForBufferRow(pos.row)
    @servers.send line, (err,res) => @showQueryResult line,err,res

  execSelect: ->
    return unless editor = @getEditor()
    return if (txt = editor.getSelectedText()).length is 0
    #txt = txt.replace(/\r/g,' ').split('\n').map (str) ->
    #  str.replace / +\/.*/, ' '
    txt = txt.replace(/\r/g,' ')
    @servers.send txt, (err,res) => @showQueryResult txt,err,res

  showQueryResult: (query,err,res) ->
    if err
      atom.notifications.addError "Query failed with: " + err.toString(), detail: "Original query:\n" + query
      return

    res.query = query; res.id = @resId++
    @results.push res
    if prev = @results[@results.length - 1 - @maxFullResults]
      prev.wmarker?.destroy()
      prev.hmarker?.destroy()
      prev.wmarker = prev.hmarker = prev.res = prev.err = null
      prev.wscroll = prev.hscroll =  false
    @results.shift() if @results.length > @maxResults

    if !pane = atom.workspace.paneForURI('kdb://query.results')
      view = require './exec-query-view'
      me = atom.workspace.getActivePane()
      pane = if @panePosition is 'right' then me.splitRight() else me.splitDown()
      return if !pane
      @resultView = new view()
      @resultView.init this
      pane.addItem editor = @resultView.getEditor()
      editor.onDidDestroy =>
        if @resultView and !@destroyed
          @resultView.destroy()
          @resultView = null
      eview = atom.views.getView(editor)
      eview.style.fontSize = @fontSize + 'px'
      me.activate()
      @resultView.addResult r for r in @results
    else @resultView.addResult res

  getEditor: ->
    return null unless editor = atom.workspace.getActiveTextEditor()
    return null unless editor.getGrammar().scopeName is "source.q"
    editor

  destroy: ->
    @destroyed = true
    @resultView?.destroy()
    @subscriptions.dispose()
    @servers = @subscriptions = @results = @resultView = null

module.exports =
  exec: new ExecQuery()
