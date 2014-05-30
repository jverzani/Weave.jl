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
# @param astext if false open in browser, else return as string
function markdownToHtml(f; 
                        tpl::String=Pkg.dir("Weave", "tpl", "weave-tpl.html"), 
                        astext::Bool=false,
                        debug::Bool=false
                        )
    
    srand(1)
    
    
    out = weave(open(f), nothing,
                template=Pkg.dir("Weave", "tpl", "pandoc-html5-tpl.html"),
                keyvals={"--highlight-style" => "tango"})
    
#    tpl = Mustache.template_from_file(tpl)
#    out = Mustache.render(tpl, {:body => out});

    if !astext
        outfile = tempname() * ".html";
        io = open(outfile, "w"); write(io, out); close(io);
        open_url(outfile)
    else
        out
    end
end