## formatting with bootstrap

## Do pagination
## pag = tabbable()
## pag.start()   ## in asis=true
## pag.next("first")
## pag.next("second")
## ...
## pag.finish()
type Tabbable
    secs::Array
    cur::Integer
    start::Function
    next::Function
    finish::Function
    function Tabbable()
        self = new()
        self.secs = String[]
        self.cur = 1
        start_tpl = "

<div id=\"tabbable\" class=\"tabbable tabs-left\">
<ul class=\"nav nav-tabs\"></ul>
<div class=\"tab-content\">
"
        first_tpl = "
<div class=\"tab-pane active\" id=\"{{value}}\">
"

        next_tpl = "

<div class=\"pagination\">
<ul><li>
<a href=\"#{{value}}\"  data-toggle=\"tab\">Next</a>
</li></ul>
</div>

</div>
<div  class=\"tab-pane\" id=\"{{value}}\">

"
        ## isn't working...
        XXXlast_tpl = "
<div>
<script>\$(\"#tabbable > ul\").html('{{#items}}<li{{active}}><a href=\"#{{value}}\" data-toggle=\"tab\">{{{label}}}</a></li>{{/items}}');</script>
"
        last_tpl = "
</div>
</div>
</div>
<script>\$(\"#tabbable > ul\").html('{{{items}}}');</script>
"

        make_value(x) = "_" * replace(lowercase(x), " ", "_") * "_"
        self.start = () -> begin
            Mustache.render(start_tpl)
        end
        self.next = (title) -> begin
            isfirst = length(self.secs) == 0
            push!(self.secs, title)
            value = make_value(title)
            Mustache.render(isfirst ? first_tpl : next_tpl, {"value"=> value})
        end
        self.finish = () -> begin
            secs = self.secs

            sections = DataFrame(active=["class=\"active\"", ["" for i in 1:length(secs)-1]], 
                                 value=map(make_value, secs), 
                                 label=secs)

            ## build up list items. Should iterate through template, but
            ## isn't working for somereason
            out = ""
            for i in 1:nrow(sections)
                active=sections[i, "active"]; value=sections[i, "value"]; label=sections[i, "label"]
                 out = out * "<li $active><a href=\"#$value\" data-toggle=\"tab\"> $label </a></li>"
             end

            Mustache.render(last_tpl, {"items"=>out})
        end
        self
    end
end

tabbable() = Tabbable()

# An example header
example(x::String) = "<span class=\"label label-warning\">Example: $(markdown(x))</span>"

# A note
note(x::String) = "<i class=\"icon-bullhorn\"></i> <span class=\"label label-important
\">$(markdown(x))</span>"


# put into a block quote
function blockquote(text::String; author::String="", source::String="")
    tpl = "
<blockquote>
{{{text}}}
{{#author}}<small>{{author}}</small>{{/author}}
{{#source}}<small><cite title=\"{{source}}\">{{source}}</cite></small>{{/source}}
</blockquote>
"
    Mustache.render(tpl, {"text"=>markdown(text, stripp=false), 
                          "author"=>author, "source"=>source})
end

# alert
function alert(text::String; title::String="", class::String="info")
    tpl = "
<div class=\"alert alert-{{class}}\">
{{^title}}<strong>{{{title}}}</strong>{{/title}}
{{{text}}}
</div>
"
    Mustache.render(tpl, {"text"=>markdown(text),
                          "class"=> class,
                          "title"=>markdown(title)
                          })
end

## Images, video, ... (XXX separate file?)


## inline this baby...
function inline_img(img::String)
    base64 = readall(`base64 $img`)
    "<img alt=\"Embedded Image\" src=\"data:image/png;base64,$base64\" />"
end




## Markup stuff
function embed_youtube(ID; width::Integer=400, height::Integer=300)
    tpl ="
  <iframe width='{{width}}' height='{{height}}' src='http://www.youtube.com/embed/{{ID}}' frameborder='0' allowfullscreen></iframe>
"
    Mustache.render(tpl)
end