# Gadfly.weave implements a system for executable documentation, report
# generation, literate programming, and such.
# It works as follows:
#   1. Input is parsed by pandoc into JSON.
#   2. Weave executes the code blocks found in the JSON data, and inserts the
#      results back into the JSON representation.
#   3. This processed JSON representation is fed back into pandoc, and output in
#      the desired format.
#
# Pandoc's extensions to markdown are used to, e.g., tag code blocks as
# producing image data, or those that should not be executed.


#export weave
import Base.parse


# A special module in which a documents code is executed.
module WeaveSandbox
    # Replace OUTPUT_STREAM references so we can capture output.
    OUTPUT_STREAM = IOString()
    print(x) = Base.print(OUTPUT_STREAM, x)
    println(x) = Base.println(OUTPUT_STREAM, x)

    # Output
    MIME_OUTPUT = Array(Tuple, 0)
    emit(mime, data) = push!(MIME_OUTPUT, (mime, data))
end

# A super-simple pandoc interface.
#
# Args:
#   input: Input string.
#   infmt: Input format.
#   outfmt: Output format.
#   args: Additional arguments appended to the pandoc command.
#
# Returns:
#   A string containing the output from pandoc.
#
function pandoc(input::String, infmt::Symbol, outfmt::Symbol, args::String...)
    cmd = ByteString["pandoc",
                     "--from=$(string(infmt))",
                     "--to=$(string(outfmt))"]
    for arg in args
        push!(cmd, arg)
    end
    pandoc_out, pandoc_in, proc = readandwrite(Cmd(cmd))
    write(pandoc_in, input)
    close(pandoc_in)
    readall(pandoc_out)
end



# An iterator for the parse function: parsit(source) will iterate over the
# expressiosn in a string.
type ParseIt
    value::String
end

## iterate over (cmd, expr)
parseit(value::String) = ParseIt(value)

import Base: start, next, done
start(it::ParseIt) = 1
function next(it::ParseIt, pos)
    (ex,newpos) = Base.parse(it.value, pos)
    ((it.value[pos:(newpos-1)], ex), newpos)
end
done(it::ParseIt, pos) = pos > length(it.value)


### From Judo.weave

# Convert a string to a structure interpretable by pandoc json parser.
function string_to_pandoc_json(s::String)
    out = {}
    for mat in eachmatch(r"\S+", s)
        if !isempty(out)
            push!(out, "Space")
        end
        push!(out, ["Str" => mat.match])
    end
    out
end


# A Display implementation that renders multimedia into the document currently
# being processed.
type WeaveDoc <: Display
    # JSON respresentation of the document being built up.
    blocks::Array

    # Queued output from display calls
    display_blocks::Array

    # Document name (used for naming any external files generated)
    name::String

    # Output formal
    outfmt::Symbol

    # Current figure number
    fignum::Int

    # Redirected stdout
    stdout_read
    stdout_write

    # Output directory
    outdir::String

    function WeaveDoc(name::String, outfmt::Symbol, stdout_read, stdout_write,
                      outdir::String)
        new({}, {}, name, outfmt, 1, stdout_read, stdout_write, outdir)
    end
end


# Display functions that render output and insert them into the document.

const supported_mime_types =
    { MIME"text/html",
      MIME"image/svg+xml",
      MIME"image/png",
      MIME"text/latex",
      MIME"text/vnd.graphviz",
      MIME"text/plain" }


function display(doc::WeaveDoc, data)
    for m in supported_mime_types
        if mimewritable(m(), data)
            display(doc, m(), data)
            break
        end
    end
end


function display(doc::WeaveDoc, m::MIME"text/plain", data)
    block =
        {"CodeBlock" =>
           {{"", {"output"}, {}}, stringmime(m, data)}}
    push!(doc.display_blocks, block)
end


function display(doc::WeaveDoc, m::MIME"text/latex", data)
    # latex to dvi
    input_path, input = mktemp()
    writemime(input, m, data)
    flush(input)
    seek(input, 0)
    latexout_dir = mktempdir()
    run(`latex -output-format=dvi -output-directory=$(latexout_dir) $(input_path)` |> SpawnNullStream())
    rm(input_path)

    # dvi to svg
    latexout_path = "$(latexout_dir)/$(basename(input_path)).dvi"
    output = readall(`dvisvgm --stdout --no-fonts $(latexout_path)` .> SpawnNullStream())
    run(`rm -rf $(latexout_dir)`)

    display(doc, MIME("image/svg+xml"), output)
end


function display(doc::WeaveDoc, m::MIME"image/svg+xml", data)
    filename = @sprintf("%s_figure_%d.svg", doc.name, doc.fignum)
    out = open(joinpath(doc.outdir, filename), "w")
    writemime(out, m, data)
    close(out)

    alttext = @sprintf("Figure %d", doc.fignum)
    figurl = filename
    caption = ""

    if doc.outfmt == :html || doc.outfmt == :html5
        block =
            {"RawBlock" =>
              {"html",
               """
               <figure>
                 <object alt="$(alttext)" data="$(figurl)" type="image/svg+xml">
                 </object>
                 <figcaption>
                   $(caption)
                 </figcaption>
               </figure>
               """}}
    else
        block =
            {"Para" =>
              {{"Image" =>
                {{{"Str" => alttext}},
                 {figurl, ""}}}}}
    end

    doc.fignum += 1
    push!(doc.display_blocks, block)
end


function display(doc::WeaveDoc, m::MIME"image/png", data)
    filename = @sprintf("%s_figure_%d.png", doc.name, doc.fignum)
    out = open(joinpath(doc.outdir, filename), "w")
    writemime(out, m, data)
    close(out)

    alttext = @sprintf("Figure %d", doc.fignum)
    figurl = filename
    caption = ""

    block =
        {"Para" =>
          {{"Image" =>
            {{{"Str" => alttext}},
             {figurl, ""}}}}}

    doc.fignum += 1
    push!(doc.display_blocks, block)
end


function display(doc::WeaveDoc, m::MIME"text/vnd.graphviz", data)
    output, input, proc = readandwrite(`dot -Tsvg`)
    writemime(input, m, data)
    close(input)
    display(doc, MIME("image/svg+xml"), readall(output))
end


function display(doc::WeaveDoc, m::MIME"text/html", data)
    block = {"RawBlock" =>
              {"html", stringmime(m, data)}}
    push!(doc.display_blocks, block)
end


# This is maybe an abuse. TODO: This is going to be a problem.
writemime(io, m::MIME"text/vnd.graphviz", data::String) = write(io, data)
writemime(io, m::MIME"image/vnd.graphviz", data::String) = write(io, data)
writemime(io, m::MIME"image/svg+xml", data::String) = write(io, data)
writemime(io, m::MIME"text/latex", data::String) = write(io, data)


# comment output ala knitr
commentify(x::String) = "## " * replace(chomp(x), "\n", "\n## ")
commentify(x) = x

# Execute an executable document.
#
# Code blocks within their own paragraph are executed, and their output is
# inserted into the document. This behavior is controlled by attributes assigned
# to the block.
#
# Args:
#   infn: Input filename.
#   infmt: Pandoc-compatible input format. E.g., markdown, rst, html, json, latex.
#   outfmt: Pandoc-compatibly output format.
#   pandoc_args: Extra arguments passed to pandoc.
#
# Returns:
#   A string in the requested output format,
#
function weave(input::IO, output::IO;
               infmt=:markdown, outfmt=:html5,
               name="judo", outdir="/tmp",
               keyvals::Dict=Dict())

    input_text = readall(input)



    # first pandoc pass
    pandoc_metadata, document =
    JSON.parse(pandoc(input_text, infmt, :json))
    prev_stdout = STDOUT
    stdout_read, stdout_write = redirect_stdout()
    doc = WeaveDoc(name, outfmt, stdout_read, stdout_write, outdir)
    pushdisplay(doc)

    sections = {}

    for block in document
        println("iterating overa block")
        if isa(block, Dict) && haskey(block, "Header")
            level, nameblocks = block["Header"]
            headername = IOBuffer()
            for subblock in nameblocks
                if subblock == "Space"
                    write(headername, " ")
                elseif isa(subblock, Dict)
                    write(headername, subblock["Str"])
                end
            end
            push!(sections, (level, takebuf_string(headername)))
            if !dryrun
                push!(doc.blocks, process_block(block))
            end
        elseif isa(block, Dict) && haskey(block, "CodeBlock")
            println("codebolcok")
            try
                process_code_block(doc, block)
            catch err
                error("Error processing codeblock in document $(name):\n$(string(err))")
            end
        else
            push!(doc.blocks, process_block(block))
        end
    end


    println("popdisplay")
    popdisplay(doc)
    println("reinit")
    Base.reinit_stdio()

    # second pandoc pass
    println("second pass")
    buf = IOBuffer()
    JSON.print(buf, {pandoc_metadata, doc.blocks})

    args = {}
    for (k, v) in keyvals
        push!(args, "--variable=$(k):$(v)")
    end

    if template != nothing
        push!(args, "--template=$(template)")
    end

    if toc
        push!(args, "--toc")
    end
    println("write")
    write(output, pandoc(takebuf_string(buf), :json, outfmt, args...))

    metadata, sections
end


# Evaluate the truthiness of a code block attribute.
function codeblock_keyval_bool(keyvals::Dict, key, default::Bool)
    haskey(keyvals, key) ?
        lowercase(strip(keyvals[key])) != "false" : default
end


# Process a text paragraph.
#
# Args:
#   block: Block parsed from the json document representation.
#
# Modifies:
#    block, prior to inserting it into doc
#
# Returns:
#   block
#
function process_block(block::Dict)
    for (k, v) in block
        if k == "Code"
            (id, classes, keyvals), text = v
            if "julia" in classes
                out = eval(WeaveSandbox, parse(text))
                v[2] = string(out)
            end
        else
            block[k] = process_block(v)
        end
    end
    block
end


function process_block(block::Array)
    for i in 1:length(block)
        block[i] = process_block(block[i])
    end
    block
end


function process_block(block::Any)
    block
end



# Code block classes supported.
const code_block_classes = Set(
    {"julia",
    "graphviz",
    "latex",
    "svg"}
)



# Process code blocks.
#
# This consists of (optioclasses =ally) executing code and inserting the results into
# the document.
#
# Args:
#   doc: Document being generated.
#   block:: Code block.
#
function process_code_block(doc::WeaveDoc, block::Dict)
    (id, classes, keyvals_array), text = block["CodeBlock"]
    keyvals = [k => v for (k, v) in keyvals_array]

    # Options are:
    #
    #  hide: Don't show the code block. (defaut: false)
    #  execute: Do excute the code block. (default: true)
    #  display: Do display output. (default: true)
    #  results:
    #    none (default)
    #    block
    #    expression

    keyvals["hide"]    = codeblock_keyval_bool(keyvals, "hide",    false)
    keyvals["execute"] = codeblock_keyval_bool(keyvals, "execute", true)
    keyvals["display"] = codeblock_keyval_bool(keyvals, "display", true)
    keyvals["results"] = get(keyvals, "results", "block")

    if isempty(classes) || classes[1] == "julia" ||
        !in(classes[1], code_block_classes)

        if keyvals["results"] == "none" || keyvals["results"] == "block"
            result = nothing
            if keyvals["execute"]
                for (cmd, ex) in parseit(strip(text))
                    result = safeeval(ex)
                end
            end

            if keyvals["results"] == "block" && result != nothing
                display(result)
            end
            output_text = text
        elseif keyvals["results"] == "expression"
            if keyvals["execute"]
                output_text = IOBuffer()
                for (cmd, ex) in parseit(strip(text))
                    println(output_text, cmd)
                    println(output_text, "## ", string(safeeval(ex)), "\n")
                end
            else
                output_text = text
            end
        end

        if !keyvals["hide"]
            push!(doc.blocks,
            {"CodeBlock" => {{id, {"julia", classes...}, keyvals_array}, output_text}})
        end

        if keyvals["display"]
            # TODO: Is there a way to check for output without this dirty trick?
            write(doc.stdout_write, '.')
            stdout_output = readavailable(doc.stdout_read)[1:end-1]
            if !isempty(stdout_output)
                display("text/plain", stdout_output)
            end
            append!(doc.blocks, doc.display_blocks)
        end
        empty!(doc.display_blocks)
    else
        if !keyvals["hide"]
            push!(doc.blocks, block)
        end

        class = classes[1]
        if keyvals["display"]
            if class == "graphviz"
                display("text/vnd.graphviz", text)
            elseif class == "latex"
                display("text/latex", text)
            elseif class == "svg"
                display("image/svg+xml", text)
            end
            append!(doc.blocks, doc.display_blocks)
        end
    end
end


# Evaluate an expression and return its result and a string.
function safeeval(ex::Expr)
    eval(WeaveSandbox, ex)
end
