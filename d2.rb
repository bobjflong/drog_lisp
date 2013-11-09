
require 'whittle'

module Tokens
  ADD = "+"
  DEFINE = "def"
  CALL = "call"
  GET = "get"
  SHOW = "show"
end

class Parser < Whittle::Parser
  
  rule(:wsp => /\s+/).skip!

  rule("(")
  rule(")")
  rule("{")
  rule("}")

  rule(:add => /\+/).as { |add| add }
  rule(:define => /Func/).as { |d| d }
  rule(:do => /Do/).as { |d| d }
  
  
  #call a func with a list of args
  rule(:call => /Call/).as { |c| c }
  rule(:show => /Show/).as { |s| s }
  rule(:name => /[a-zA-Z]+/).as { |n| n }
  rule(:const => /[0-9]+/).as { |n| n.to_i }

  rule(:expr) do |r|
    r["(", :do, :expression_list, ")"].as { |_,_,a,_| a }
  end
  
  rule(:expression_list) do |r|
    r[:inner_expr, :expression_list].as do |a,b|
      [a] + [b]
    end
    r[]
  end
  
  rule(:inner_expr) do |r|
 
    r["(", :define, :name, :param_list, ")", :expr].as do |_,_,n,p,_,e| 
      [ Tokens::DEFINE, n, p, e ]
    end
 
    r["(", :show, :inner_expr, ")"].as do |_,_,n,a|
      [Tokens::SHOW, n, a]
    end
    
    r["(", :call, :name, :argument_list, ")"].as do |_,_,n,a|
      [Tokens::CALL, n, a]
    end
 
    r["(", :add, :inner_expr, :inner_expr, ")"].as { |_,_,a,b,_| [ Tokens::ADD, a, b  ] }
    r[:name].as { |n| [Tokens::GET, n] }
    r[:const].as { |c| c }    
  end
  
  
  rule(:param_list) do |r|
    r[:name, :param_list].as { |n, a| ([n] + [a]).flatten }
    r[:name].as { |n| n }
  end

  rule(:argument_list) do |r|
    r[:name, :argument_list].as { |n, a| ([n] + [a]).flatten }
    r[:name].as { |n| [Tokens::GET, n] }
    r[:const].as { |c| c }
  end

  start(:expr)
end

