
require 'whittle'
require 'sxp'

module Tokens
  ADD = "+"
  DEFINE = "def"
  SET = "set"
  CALL = "call"
  STRUCT = "struct"
  GET = "get"
  SHOW = "show"
  LT = "<"
  IF = "if"
  MUL = "*"
  SUB = "-"
  CONS = "cons"
  EQ = "="
  CONST = "const"
  CAR = "car"
  CDR = "cdr"
  LET = "let"
  GETS = "gets"
  CallCC = "callcc"
  QUOTE = "quote"
  EVALUATE = "evaluate"
end

class Parser < Whittle::Parser
  

  
  rule(:wsp => /\s+/).skip!

  rule("(")
  rule(")")
  rule("{")
  rule("}")
  rule("<")
  rule("~")
  
  rule(:eq => /\=/).as { |eq| eq }
  rule(:car => /Car/).as { |car| car }
  rule(:cdr => /Cdr/).as { |cdr| cdr }
  rule(:callcc => /CallCC/).as { |callcc| callcc }
  rule(:sub => /\-/).as { |sub| sub }
  rule(:mul => /\*/).as { |mul| mul }
  rule(:add => /\+/).as { |add| add }
  rule(:define => /Func/).as { |d| d }
  rule(:cons => /Cons/).as { |c| c }
  rule(:do => /Do/).as { |d| d }
  rule(:null => /null/).as { |n| n }
  
  rule(:evaluate => /Evaluate/).as { |e| e }
  rule(:gets => /Get\-[a-zA-Z\-]+/).as { |g| g }
  rule(:set => /Set\-[a-zA-Z\-]+/).as { |s| s }
  #call a func with a list of args
  rule(:call => /Call/).as { |c| c }
  rule(:struct => /Struct/).as { |s| s }
  rule(:quote => /\'/).as { |q| q }
  rule(:let => /Let/).as { |l| l }
  rule(:if => /If/).as { |i| i }
  rule(:show => /Show/).as { |s| s }
  rule(:name => /[a-zA-Z\-]+/).as { |n| n }
  rule(:reserved => /[\+\-\\\*]/).as { |n| n }
  rule(:const => /([0-9]+)|(\'[a-zA-Z\-]*\')/).as do |n| 
    if not n[0] == "'" then
      n.to_i
    else
      n[1..-2]
    end
  end
  
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
 
    r["(", :define, :name, :param_list, :closure_list, ")", :expr].as do |_,_,n,p,c,_,e| 
      [ Tokens::DEFINE, n, p, c, e ]
    end
 
    r["(", :let, :name, :deducted_value, ")"].as do |_,_,n,v,_|
      [ Tokens::LET, n, v ]
    end
 
    r["(", :show, :inner_expr, ")"].as do |_,_,n,_|
      [Tokens::SHOW, n ]
    end

    r["(", :set, :deducted_value, :deducted_value, ")"].as do |_,s,k,v,_|
      [ Tokens::SET, s, k, v ]
    end
 
    r[:deducted_value].as { |d| d }   
  end
  
  rule(:closure_list) do |r|
    r["~", "(", :param_list, ")"].as { |_,_,c,_| c }
    r[]
  end
  
  rule(:deducted_value) do |r|

    r["(", :evaluate, :deducted_value, ")"].as do |_,_,d|
      [ Tokens::EVALUATE, d]
    end
    
    r["(", :struct, :param_list, ")"].as do |_,_,p|
      [ Tokens::STRUCT, p ]
    end

    r["(", :gets, :deducted_value, ")"].as do |_,g,v|
      [ Tokens::GETS, g, v ]
    end
    
    r["(", :call, :name, :argument_list, ")"].as do |_,_,n,a|
      result = [Tokens::CALL, n]
      if a.length > 0 and not a[0].kind_of? Array
        #single element arg list
        a = [a]
      end
      a.each do |p|
        result << p
      end
      result
    end

    r["(", :callcc, :name, ")"].as do |_,_,v|
      [ Tokens::CallCC, v ]
    end
    
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

    r["(", :car, :inner_expr, ")"].as { |_,_,a| [ Tokens::CAR, a ] }
    r["(", :cdr, :inner_expr, ")"].as { |_,_,a| [ Tokens::CDR, a ] }

    
    r["(", :mul, :inner_expr, :inner_expr, ")"].as do |_,_,a,b,_|
      [ Tokens::MUL, a, b ]
    end
    
    r[:name].as { |n| [Tokens::GET, n] }
    r["(", :name, ")"].as { |_,n| [Tokens::GET, n] }
    r[:const].as { |c| [Tokens::CONST, c] } 
    r["(", :const, ")"].as { |_,c| [Tokens::CONST, c] }
    r[:null].as { |_| nil }

    r[:quoted].as { |q| q }
    
  end

  rule(:quoted) do |r|
    #allow some operators
    r[:quote, :add].as { |_,x| [Tokens::QUOTE, SXP.read(x)] } 
    r[:quote, :sub].as { |_,x| [Tokens::QUOTE, SXP.read(x)] }
    r[:quote, :mul].as { |_,x| [Tokens::QUOTE, SXP.read(x)] } 
    r[:quote, :name].as {|_,x| [Tokens::QUOTE, SXP.read(x)] }
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

