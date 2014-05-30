## Open a url using our heuristic
function open_url(url::String) 
    @osx_only     run(`open $url`)
    @windows_only run(`start $url`)
    @linux_only   run(`xdg-open $url`)
end


# Format for displaying googlechart
## gadfly_format(p::GoogleCharts.CoreChart) = GoogleCharts.gadfly_format(p)

# format for display gadfly through asis (without calling draw(D3(...)))
# function gadfly_format(p::Union(Gadfly.Plot, Compose.CanvasTree)) 
#     tpl = "
# <div id='{{id}}'></div>
# <script>
# {{{script}}};
# draw('#{{id}}');
# </script>
# "

#     f = tempname() * ".js"
#     draw(D3(f, 6inch, 4inch), p)
#     io = open(f)
#     x = readlines(io) |> join
#     close(io); rm(f)
#     Mustache.render(tpl, {"id"=> randstring(10),
#                           "script" => x})
# end