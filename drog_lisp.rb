
require 'whittle'

$symbol_table = [{}]
$argument_stack = []

def new_scope
  $symbol_table << {}
end

def print_symbol_table
  puts $symbol_table
end

module Tokens
  ADD = "*"
  MUL = "*"
  SUB = "-"
  GET = "GET"
  SET = "SET"
  

class LispMaker < Whittle::Parser

  rule(:wsp => /\s+/).skip! #skip whitespace

  rule("(")
  rule(")")
  rule("]")
  rule(",")

  rule(:add => /Add/).as { |add| add }
  rule(:mul => /Mul/).as { |mul| mul }
  rule(:sub => /Sub/).as { |sub| sub }
  rule(:def => /Def/).as { |d|     d }
  rule(:get => /Get/).as { |g|     g }
  rule(:let => /Let/).as { |l|     l }
  rule(:show=> /Show/).as { |s|    s }
  rule(:call => /Call/).as { |c| c }
  rule(:name => /[a-zA-Z]+/).as { |n| n }
  rule(:constant => /[0-9]+/).as { |c| c.to_i }
  rule(:arg_start => /\[/).as { |as| puts "emptying argument stack"; $argument_stack = []; as }

  rule(:expr) do |r|
    r["(", :constant, ")"].as { |_, n, _| n }
    r["(", :show, :expr, ")"].as      { |_,_,n,_|   puts n }
    r["(", :add, :expr, :expr, ")"].as { |_,_,n1,n2,_| n1 + n2 }
    r["(", :mul, :expr, :expr, ")"].as { |_,_,n1,n2,_| n1 * n2 }
    r["(", :sub, :expr, :expr, ")"].as { |_,_,n1,n2,_| n1 - n2 }
    r["(", :let, :definition, :expr, ")"].as { |_,_,_,n,_| n; print_symbol_table() }
    r["(", :get, :name, ")"].as { |_,_,n,_| $symbol_table[-1][n] }
    r["(", :call, :argument_list, ")"].as { puts "arg list: "; puts $argument_stack }
    r[]
  end
  
  rule(:argument_list) do |r|
    r[:arg_start, :arg, "]"].as { |_,_,_| $argument_stack }
    r[]
  end
  
  rule(:arg) do |r|
    r[:arg_val, ",", :arg].as { |n,_,_|  $argument_stack << n }
    r[:arg_val].as { |n|  $argument_stack << n }
  end
  
  rule(:arg_val) do |r|
    r[:name].as { |n| $symbol_table[-1][n] }
    r[:constant].as { |c| c }
  end

  rule(:definition) do |r|
    r["(", :def, :name, :expr, ")"].as do |_,_,n1,n2,_|
      $symbol_table[-1][n1] = n2
      nil
    end
  end
  
  rule(:any => /.*/).as { |any| any }

  start(:expr)
end

puts LispMaker.new.parse(File.new(ARGV[0]).read)
