module Weave

using JSON
using Compose
using Codecs
using Mustache
using Gadfly
using GoogleCharts
using DataFrames

import Gadfly.gadfly_format

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
