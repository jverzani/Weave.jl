weave_args = [ "--mathjax",  "--highlight-style=tango"]

# markdown
# 
# `x` string to convert
# `args...` pandoc args
# `stripp` if false, leave enclosing <p></p>, otherwise drop
# take a string and replace with html from weave
# special case "" -> ""
#
function markdown(x::String, args...; stripp::Bool=true)
    if length(x) == 0 
        return("")
    end

    out = weave(IOBuffer(x), nothing, 
                keyvals={"--highlight-style" => "tango"})
    chomp(out)
end
    



# markdownToHtml
#
# take file, convert to html, put into template
# @param f  filename
# @param tpl optional Mustache template
# @param out filename or empty to display in browser
function markdownToHtml(f; 
                        out::String="",
                        tpl::String=Pkg.dir("Weave", "tpl", "weave-tpl.html"), 
                        debug::Bool=false
                        )
    
    srand(1)
    
    
    output = weave(open(f), nothing,
                   template=Pkg.dir("Weave", "tpl", "pandoc-html5-tpl.html"),
                   keyvals={"--highlight-style" => "tango"})
    
    #    tpl = Mustache.template_from_file(tpl)
    #    out = Mustache.render(tpl, {:body => out});
    
    
    
    outfile = (out == "" ?  tempname() * ".html" : out)
    io = open(outfile, "w")
    write(io, output) 
    close(io)
    
    out == "" && open_url(outfile)
end
