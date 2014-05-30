module Weave

using JSON
using Codecs
using Mustache
using DataFrames

##using Judo
## using GoogleCharts
#using Compose


# import Gadfly.gadfly_format
#include("gadfly_weave.jl")
include("judo_weave.jl")
include("utils.jl")
include("interfaces.jl")
include("bootstrap.jl")
include("questions.jl")


export markdown, markdownToHtml
export tabbable, example, note, blockquote, alert, 
       inline_img, embed_youtube
export radioq, choiceq, booleanq, numericq
export gadfly_format




end
