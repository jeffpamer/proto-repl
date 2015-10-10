{Task} = require 'atom'
path = require 'path'
ReplProcess = require.resolve './repl-process'


replHelpText = ";; This is a text editor and also a Clojure REPL.  It behaves
differently than a typical Clojure REPL. You can type anywhere and modify any of
the displayed text. Commands are not sent by typing in the REPL and pressing
enter. They are sent through keyboard shortcuts.\n
\n
;; REPL Execution Keybindings\n
;; Note: These keybindings can be executed from any file and the results will be
displayed in this REPL.\n
;; See the settings for more keybindings.\n
\n
;; cmd+alt+b - execute block. Finds the block of Clojure code your cursor is in
and executes that.\n
\n
;; Try it now. Put your cursor inside this block and press cmd+alt+b\n
(+ 2 3)\n
\n
;; cmd+alt+s - Executes the selection. Sends the selected text to the REPL.\n
\n
;; Try it now. Select these three lines and hit cmd + alt + s.\n
(println \"hello 1\")\n
(println \"hello 2\")\n
(println \"hello 3\")\n
\n
;; You can disable this help text in the settings.\n"

module.exports =
class ReplTextEditor
  # This is set to some string to strip out of the text displayed. It is used to remove code that
  # is sent to the repl because the repl will print the code that was sent to it.
  textToIgnore: null

  constructor: ->
    projectPath = atom.project.getPaths()[0]

    closingHandler =  =>
      try
        @process.send event: 'input', text: "(System/exit 0)\n"
      catch error
        console.log("Warning error while closing: " + error)

    atom.workspace.open("Clojure REPL", split:'right').done (textEditor) =>
      @textEditor = textEditor
      grammar = atom.grammars.grammarForScopeName('source.clojure')
      @textEditor.setGrammar(grammar)
      @textEditor.onDidDestroy(closingHandler)
      @textEditor.setSoftWrapped(true)

      if atom.config.get("proto-repl.displayHelpText")
        @textEditor.insertText(replHelpText)

      @textEditor.insertText(";; Loading REPL...\n")

    @process = Task.once ReplProcess,
                         path.resolve(projectPath),
                         atom.config.get('proto-repl.leinPath'),
                         atom.config.get('proto-repl.leinArgs').split(" ")
    @attachListeners()

  strToBytes: (s)->
    s.charCodeAt(n) for n in [0..s.length]

  autoscroll: ->
    if atom.config.get('proto-repl.autoScroll')
      @textEditor.scrollToBottom()

  attachListeners: ->
    @process.on 'proto-repl-process:data', (data) =>
      @textEditor.getBuffer().append(data)
      @autoscroll()

    @process.on 'proto-repl-process:exit', ()=>
      @textEditor.getBuffer().append("REPL Closed")
      @autoscroll()

  sendToRepl: (text)->
    @process.send event: 'input', text: text + "\n"

  clear: ->
    @textEditor.setText("")