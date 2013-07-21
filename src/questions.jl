type QuestionID
    cnt::Integer
    inc::Function
    init::Function
    function QuestionId() 
        self = new(0)
        self.inc = () -> self.inc = self.inc + 1
        self.init = () -> self.inc = 0
        self
    end
end


function question_id()
    randstring(10)
end


## Something like this: (though combo boxes aren't working!)
# ~~~{.julia results="asis"}
# begin
# insert_simple_questions()
# end
# ~~~

# <script type="text/markdown">
# Question 1 =  () one () two (x) three

# Question 2 = ___[25]

# Question 3 = {BOS -> Boston, SFC -> San Francisco, (ANS -> New York)}
# </script>

function insert_simple_questions()
    ## add wmd stuff for easy question writing. See Weave. No interpolation here
"
<!-- Super hacky way to get self-grading quiz questions -->
<script src='https://raw.github.com/jverzani/wmd/master/showdown2.js'></script>
  <script>
    \$(function() {
      // replace markdown text 
      \$('script[type='text/markdown']').after(function(index){
        converter = new Showdown.converter();
        out = converter.makeHtml(this.text);
        return(out)
      });
    });
</script>
<script>
/* Super simple Growl-like notification v0.1
 * Copyright 2010 Sebastian Wallin 
 * licensed under the MIT license
 */
(function(b){b.fn.extend({notify:function(a){var c=this;a=b.extend({text:'',addClass:'',duration:3E3,sticky:false},a);var e=b('<div></div>').addClass('notice-outer').appendTo(this[0]);this.item=b('<div></div>').html(a.text).addClass('notice-inner').addClass(a.addClass).appendTo(e);a.sticky?b('<span>x</span>').click(function(){c.disappear()}).appendTo(this.item):setTimeout(function(){c.disappear()},a.duration);this.disappear=function(){var d=this.item;d.parent().animate({opacity:'0',height:'0px'},300,function(){d.parent().remove()})};return this}})})(jQuery);
function growl(msg, container) { \$('#' + container).notify({text:msg,duration:1000,addClass:'alert'});};
function gripe(msg, container) { \$('#' + container).notify({text:msg,duration:500,addClass:'alert alert-error'});};
</script>
"
end






##################################################


## Template for form element with bootstrap styling
## XXX needs {{{hint}}}
qtpl = "
<form name='WeaveQuestion' data-id='{{ID}}' data-controltype='{{TYPE}}'>
<div class='control-group {{status}}'>
<div class='controls'>
{{{form}}}
{{#hint}}
<span class='help-inline'><i id='{{ID}}_hint' class='icon-gift'></i></span>
<script>\$('#{{ID}}_hint').tooltip({title:'{{{hint}}}', html:true, placement:'right'});</script>
{{/hint}}
<div id='{{ID}}_message'></div>
</div>
</div>
</form>
<script text='text/javascript'>
{{{script}}}
</script>
"

## XXX abstract out script for checking...
script_tpl = "
\$('{{{selector}}}').on('change', function() {
  correct = {{{correct}}};

  if(correct) {
     \$('#{{ID}}_message').html('<div class=\"alert alert-success\"><i class=\"icon-thumbs-up\"></i>&nbsp;Correct</div>');
  } else {
     \$('#{{ID}}_message').html('<div class=\"alert alert-error\"><i class=\"icon-thumbs-down\"></i>&nbsp;Incorrect</alert>');
  }
});
"


# A choice (radio buttons) question
#
# choices a vector of choices
# ans index of answer
# hint optional hint
# inline if true will render inline
function radioq(choices, ans::Integer; hint::String="", inline::Bool=false)
    tpl = "
{{#items}}
<label class='radio{{inline}}'>
  <input type='radio' name='radio_{{ID}}' value='{{value}}'>
  {{{label}}}
</label>
{{/items}}
"


    ID = question_id()
    choices = map(string, choices)
    items = Dict[]
    ## make items
    for i in 1:length(choices)
        item = {"no"=>i,
                "label"=>markdown(choices[i]),
                "value"=>i
                }
        push!(items, item)
    end

    script = Mustache.render(script_tpl,
                             {"ID"=>ID, 
                              "selector"=>"input:radio[name=\"radio_$ID\"]",
                              "correct"=>"this.value == $ans"})
    
    form = Mustache.render(tpl, {"ID"=>ID, "items"=>items,
                                 "inline" => inline ? " inline" : ""
                                 })

    Mustache.render(qtpl, {"form"=>form, "script"=>script, 
                           "TYPE"=>"radio",
                           "ID"=>ID, "hint"=>markdown(hint)})
end


# A true/false question using radio button
#
# ans boolean
function booleanq(ans::Bool; hint::String="")
    radioq(["true", "false"], ans == true ? 1 : 2, hint=hint, inline=true)
end



# A choice (combobox) question
#
# choices vector of choices
# ans index of correct one
# hint optional hint
function choiceq(choices::Vector, ans::Integer; hint::String="")

    tpl = "
<select id='{{ID}}'>
{{#items}}
<option value='{{value}}'>{{{label}}}</option>
{{/items}}
</select>
<script>\$('#{{ID}}').prop('selectedIndex', -1);</script>
"


    ID = question_id()

    items = Dict[]
    for i in 1:length(choices)
        item = {"no"=>i,
                "label"=>markdown(choices[i]),
                "value"=>i
                }
        push!(items, item)
    end

    script = Mustache.render(script_tpl, 
                             {"ID"=>ID, 
                              "selector"=>"#$ID",
                              "correct" => "this.value == $ans"
                              })
    form = Mustache.render(tpl, {"ID"=>ID, "items"=>items})
    
    Mustache.render(qtpl, {"form"=>form, "script"=>script, 
                           "TYPE"=>"choice",
                           "ID"=>ID, "hint"=>markdown(hint)})
end


# A numeric question
#
# ans value
# tol a tolerance
# hint optional hint
function numericq(ans::Number, tol::Number=sqrt(eps()); hint::String="")
    tpl = "
<input id='{{ID}}' type='number'>
"

    ID = question_id()
    form = Mustache.render(tpl, {"ID"=>ID})
    script = Mustache.render(script_tpl,  
                             {"ID"=>ID, 
                              "selector"=>"#$ID",
                              "correct"=>"Math.abs(this.value - $ans) <= $tol"
                              })
    Mustache.render(qtpl, {"form"=>form, "script"=>script, 
                           "TYPE"=>"numeric",
                           "ID"=>ID, "hint"=>markdown(hint)})
end


# a text question
#
# ans a JavaScript regular expression
function textq(ans::String; hint::String="", case_insensitive::Bool=false)
     tpl = "
<input id='{{ID}}' type='text'>
    "
    
    ID = question_id()
    form = Mustache.render(tpl, {"ID"=>ID})

    do_case = case_insensitive ? ",'i'" : ""
    script = Mustache.render(script_tpl,  
                             {"ID"=>ID, 
                              "selector"=>"#$ID",
                              "correct"=>"RegExp('$ans'$do_case).test(this.value)"
                              })
    Mustache.render(qtpl, {"form"=>form, "script"=>script, 
                           "TYPE"=>"text",
                           "ID"=>ID, "hint"=>markdown(hint)})
end