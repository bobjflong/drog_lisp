
require 'whittle'

module Tokens
  ADD = "+"
  DEFINE = "def"
  CALL = "call"
  GET = "get"
  SHOW = "show"
  LT = "<"
  IF = "if"
  MUL = "*"
  SUB = "-"
  CONS = "cons"
  EQ = "="
  CONST = "const"
end

class Parser < Whittle::Parser
  

  
  rule(:wsp => /\s+/).skip!

  rule("(")
  rule(")")
  rule("{")
  rule("}")
  rule("<")
  
  rule(:eq => /\=/).as { |eq| eq }
  rule(:sub => /\-/).as { |sub| sub }
  rule(:mul => /\*/).as { |mul| mul }
  rule(:add => /\+/).as { |add| add }
  rule(:define => /Func/).as { |d| d }
  rule(:cons => /Cons/).as { |c| c }
  rule(:do => /Do/).as { |d| d }
  rule(:null => /null/).as { |n| n }
  
  #call a func with a list of args
  rule(:call => /Call/).as { |c| c }
  
  rule(:if => /If/).as { |i| i }
  rule(:show => /Show/).as { |s| s }
  rule(:name => /[a-zA-Z\-]+/).as { |n| n }
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
 
    r["(", :show, :inner_expr, ")"].as do |_,_,n,_|
      [Tokens::SHOW, n ]
    end
    
    r["(", :call, :name, :argument_list, ")"].as do |_,_,n,a|
      result = [Tokens::CALL, n]
     # if a.length > 1
        #a = a.flatten 1
      #end
      #puts "arg list; #{a}"
      if a.length > 0 and not a[0].kind_of? Array
        #single element arg list
        a = [a]
      end
      a.each do |p|
        #puts "PARAM #{p}"
        result << p
      end
      result
    end
 
    r[:deducted_value].as { |d| d }   
  end
  
  rule(:deducted_value) do |r|
    r["(", "<", :inner_expr, :inner_expr, ")"].as do |_,_,a,b,_|
      [ Tokens::LT, a, b ]
    end
    
    r["(", :if, :inner_expr, :inner_expr, :inner_expr, ")"].as do |_,_,a,b,c,_|
      [ Tokens::IF, a, b, c ]
    end
    
    r["(", :cons, :inner_expr, :inner_expr, ")"].as do |_,_,a,b,_|
      [ Tokens::CONS, a, b ]
    end
    
    r["(", :eq, :inner_expr, :inner_expr, ")"].as { |_,_,a,b,_| [Tokens::EQ, a, b] }
    
    r["(", :add, :inner_expr, :inner_expr, ")"].as { |_,_,a,b,_| [ Tokens::ADD, a, b ] }
    
    r["(", :sub, :inner_expr, :inner_expr, ")"].as { |_,_,a,b,_| [ Tokens::SUB, a, b ] }

    
    r["(", :mul, :inner_expr, :inner_expr, ")"].as do |_,_,a,b,_|
      [ Tokens::MUL, a, b ]
    end
    
    r[:name].as { |n| [Tokens::GET, n] }
    r[:const].as { |c| [Tokens::CONST, c] }
    r[:null].as { |_| nil }
  end
  
  
  rule(:param_list) do |r|
    r[:name, :param_list].as { |n, a| ([n] + [a]) }
    r[:name].as { |n| n }
  end

  rule(:argument_list) do |r|
    r[:deducted_value].as { |d| d }
    r[:deducted_value, :argument_list].as { |n, a| ([n] + [a]) }
  end

  start(:expr)
end

