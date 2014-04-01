punycode = require 'punycode'
{React, div, span, input} = require 'reactionary'
{last} = require 'underscore-plus'
{$$} = require 'space-pencil'

DummyLineNode = $$ ->
  @div className: 'line', style: 'position: absolute; visibility: hidden;', -> @span 'x'

module.exports =
React.createClass
  pendingScrollTop: null

  statics: {DummyLineNode}

  render: ->
    div className: 'editor',
      div className: 'scroll-view', ref: 'scrollView',
        InputComponent ref: 'hiddenInput', className: 'hidden-input', onInput: @onInput
        @renderScrollableContent()
      div className: 'vertical-scrollbar', ref: 'verticalScrollbar', onScroll: @onVerticalScroll,
        div outlet: 'verticalScrollbarContent', style: {height: @getScrollHeight()}

  renderScrollableContent: ->
    height = @props.editor.getScreenLineCount() * @state.lineHeight
    WebkitTransform = "translateY(#{-@state.scrollTop}px)"

    div className: 'scrollable-content', style: {height, WebkitTransform},
      @renderOverlayer()
      @renderVisibleLines()

  renderOverlayer: ->
    {lineHeight, charWidth} = @state

    div className: 'overlayer',
      for selection in @props.editor.getSelections()
        SelectionComponent({selection, lineHeight, charWidth})

  renderVisibleLines: ->
    [startRow, endRow] = @getVisibleRowRange()
    precedingHeight = startRow * @state.lineHeight
    followingHeight = (@props.editor.getScreenLineCount() - endRow) * @state.lineHeight

    div className: 'lines', ref: 'lines', [
      div className: 'spacer', key: 'top-spacer', style: {height: precedingHeight}
      (for tokenizedLine in @props.editor.linesForScreenRows(startRow, endRow - 1)
        LineComponent({tokenizedLine, key: tokenizedLine.id}))...
      div className: 'spacer', key: 'bottom-spacer', style: {height: followingHeight}
    ]

  getInitialState: ->
    height: 0
    width: 0
    lineHeight: 0
    scrollTop: 0

  componentDidMount: ->
    @props.editor.on 'screen-lines-changed', @onScreenLinesChanged
    @refs.scrollView.getDOMNode().addEventListener 'mousewheel', @onMousewheel
    @updateAllDimensions()
    @props.editor.setVisible(true)
    @refs.hiddenInput.focus()

  componentWillUnmount: ->
    @props.editor.off 'screen-lines-changed', @onScreenLinesChanged
    @getDOMNode().removeEventListener 'mousewheel', @onMousewheel

  onVerticalScroll: ->
    animationFramePending = @pendingScrollTop?
    @pendingScrollTop = @refs.verticalScrollbar.getDOMNode().scrollTop
    unless animationFramePending
      requestAnimationFrame =>
        @setState({scrollTop: @pendingScrollTop})
        @pendingScrollTop = null

  onMousewheel: (event) ->
    @refs.verticalScrollbar.getDOMNode().scrollTop -= event.wheelDeltaY
    event.preventDefault()

  onInput: (char, replaceLastChar) ->
    @props.editor.insertText(char)

  onScreenLinesChanged: ({start, end}) ->
    [visibleStart, visibleEnd] = @getVisibleRowRange()
    @forceUpdate() unless end < visibleStart or visibleEnd <= start

  getVisibleRowRange: ->
    return [0, 0] unless @state.lineHeight > 0

    heightInLines = @state.height / @state.lineHeight
    startRow = Math.floor(@state.scrollTop / @state.lineHeight)
    endRow = Math.ceil(startRow + heightInLines)
    [startRow, endRow]

  getScrollHeight: ->
    @props.editor.getLineCount() * @state.lineHeight

  updateAllDimensions: ->
    {height, width} = @measureScrollViewDimensions()
    {lineHeight, charWidth} = @measureLineDimensions()
    @setState({height, width, lineHeight, charWidth})

  measureScrollViewDimensions: ->
    scrollViewNode = @refs.scrollView.getDOMNode()
    {height: scrollViewNode.clientHeight, width: scrollViewNode.clientWidth}

  measureLineDimensions: ->
    linesNode = @refs.lines.getDOMNode()
    linesNode.appendChild(DummyLineNode)
    lineHeight = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    linesNode.removeChild(DummyLineNode)
    {lineHeight, charWidth}

LineComponent = React.createClass
  render: ->
    div className: 'line', dangerouslySetInnerHTML: {__html: @buildInnerHTML()}

  buildInnerHTML: ->
    if @props.tokenizedLine.text.length is 0
      "<span>&nbsp;</span>"
    else
      @buildScopeTreeHTML(@props.tokenizedLine.getScopeTree())

  buildScopeTreeHTML: (scopeTree) ->
    if scopeTree.children?
      html = "<span class='#{scopeTree.scope.replace(/\./g, ' ')}'>"
      html += @buildScopeTreeHTML(child) for child in scopeTree.children
      html
    else
      "<span>#{scopeTree.value}</span>"

  shouldComponentUpdate: -> false

InputComponent = React.createClass
  render: ->
    input className: @props.className, ref: 'input'

  getInitialState: ->
    {lastChar: ''}

  componentDidMount: ->
    @getDOMNode().addEventListener 'input', @onInput
    @getDOMNode().addEventListener 'compositionupdate', @onCompositionUpdate

  # Don't let text accumulate in the input forever, but avoid excessive reflows
  componentDidUpdate: ->
    if @lastValueLength > 500 and not @isPressAndHoldCharacter(@state.lastChar)
      @getDOMNode().value = ''
      @lastValueLength = 0

  # This should actually consult the property lists in /System/Library/Input Methods/PressAndHold.app
  isPressAndHoldCharacter: (char) ->
    @state.lastChar.match /[aeiouAEIOU]/

  shouldComponentUpdate: -> false

  onInput: (e) ->
    valueCharCodes = punycode.ucs2.decode(@getDOMNode().value)
    valueLength = valueCharCodes.length
    replaceLastChar = valueLength is @lastValueLength
    @lastValueLength = valueLength
    lastChar = String.fromCharCode(last(valueCharCodes))
    @props.onInput?(lastChar, replaceLastChar)

  focus: ->
    @getDOMNode().focus()

SelectionComponent = React.createClass
  render: ->
    console.log "render selection component"

    {selection, lineHeight, charWidth} = @props
    {cursor} = selection
    div className: 'selection',
      CursorComponent({cursor, lineHeight, charWidth})

CursorComponent = React.createClass
  render: ->
    {cursor, lineHeight, charWidth} = @props
    {row, column} = cursor.getScreenPosition()

    console.log "char width", charWidth

    div className: 'cursor', style: {
      height: lineHeight,
      width: charWidth
      top: row * lineHeight
      left: column * charWidth
    }
