
require 'whittle'
require 'sxp'

module Tokens
  SEND = "send"
  ADD = "+"
  DEFINE = "def"
  SET = "set"
  CALL = "call"
  APPLY= "apply"
  STRUCT = "struct"
  GET = "get"
  SHOW = "show"
  LT = "<"
  LOOPUNTIL = "loopuntil"
  IF = "if"
  MUL = "*"
  DIV = "/"
  SUB = "-"
  CONS = "cons"
  EQ = "="
  CONST = "const"
  CAR = "car"
  CDR = "cdr"
  LET = "let"
  RESET = "reset"
  GETS = "gets"
  CallCC = "callcc"
  QUOTE = "quote"
  EVALUATE = "evaluate"
  RECCALL = "reccall"
  MOD="%"
end

module GrammarHelpers

  def self.add_arguments result, a
    a.each do |to_add|
      if to_add[0].kind_of? Array
        add_arguments result, to_add
      else
        result << to_add
      end
    end
  end
  
  def self.gather_arguments result, a
    if a.length > 0 and not a[0].kind_of? Array
      #single element arg list
      a = [a]
    end
    add_arguments result, a
    result
  end

end

class Parser < Whittle::Parser
  

  
  rule(:wsp => /\s+/).skip!

  rule("(")
  rule(")")
  rule("{")
  rule("}")
  rule("<")
  rule("~")
  rule("/")
  
  rule(:eq => /\=/).as { |eq| eq }
  rule(:car => /Car/).as { |car| car }
  rule(:cdr => /Cdr/).as { |cdr| cdr }
  rule(:callcc => /CallCC/).as { |callcc| callcc }
  rule(:sub => /\-/).as { |sub| sub }
  rule(:mul => /\*/).as { |mul| mul }
  rule(:mod => /\%/).as { |mod| mod }
  rule(:div => /\//).as { |div| div }  
  rule(:add => /\+/).as { |add| add }
  rule(:define => /Func/).as { |d| d }
  rule(:cons => /Cons/).as { |c| c }
  rule(:do => /Do/).as { |d| d }
  rule(:null => /null/).as { |n| n }
  rule(:loopuntil => /LoopUntil/).as { |l| l }  
  rule(:evaluate => /Evaluate/).as { |e| e }
  rule(:gets => /Get\-[a-zA-Z\-]+/).as { |g| g }
  rule(:set => /Set\-[a-zA-Z\-]+/).as { |s| s }
  #call a func with a list of args
  rule(:reccall => /RecCall/).as { |c| c }
  rule(:call => /Call/).as { |c| c }
  rule(:apply => /Apply/).as { |a| a }
  rule(:struct => /Struct/).as { |s| s }
  rule(:quote => /\:[A-Za-z\+\-\\\*\~]+/).as { |q| q }
  rule(:send => /Send/).as { |s| s }
  rule(:let => /Let/).as { |l| l }
  rule(:reset => /Reset/).as { |s| s }
  rule(:if => /If/).as { |i| i }
  rule(:show => /Show/).as { |s| s }
  rule(:name => /[a-zA-Z\-\_\?]+/).as { |n| n }
  rule(:reserved => /[\+\-\\\*]/).as { |n| n }
  rule(:const => /([0-9]+)|((\")[^\"]*(\"))/).as do |n| 
    if not n[0] == '"'  then
      n.to_i
    else
      n[1..-2]
    end
  end
  rule(:comment => /\;[^\n]*$/).skip!
  
  rule(:expr) do |r|
    r["(", :do, :expression_list, ")"].as { |_,_,a,_| a }
    r["(", :expr, ")"].as { |_,e,_| e }
  end
  
  rule(:expression_list) do |r|
    r[:inner_expr, :expression_list].as do |a,b|
      [a] + [b]
    end
    r["(", :inner_expr, :expression_list, ")"].as do |_,a,b,_|
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

    r["(", :reset, :name, :deducted_value, ")"].as do |_,_,n,v,_|
      [ Tokens::RESET, n, v]
    end

    r["(", :loopuntil, :deducted_value, :expr, ")"].as do |_,_,v,e|
      [ Tokens::LOOPUNTIL, v, e]
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

    r["(", :send, :deducted_value, :deducted_value, ")"].as do |_,_,m,v|
      [ Tokens::SEND, m ,v]
    end

    r["(", :gets, :deducted_value, ")"].as do |_,g,v|
      [ Tokens::GETS, g, v ]
    end

    #refactor
    r["(", :call, :name, :argument_list, ")"].as do |_,_,n,a|
      result = [Tokens::CALL, n]
      GrammarHelpers::gather_arguments result, a 
    end

    r["(", :call, :inner_expr, :argument_list, ")"].as do |_,_,n,a|
      result = [Tokens::CALL, n]
      GrammarHelpers::gather_arguments result, a 
    end

    r["(", :apply, :inner_expr, :deducted_value, ")"].as do |_,_,n,a|
      [Tokens::APPLY, n, a]
    end

    r["(", :reccall, :name, :argument_list, ")"].as do |_,_,n,a|
      result = [Tokens::RECCALL, n]
      GrammarHelpers::gather_arguments result, a 
    end

    r["(", :reccall, :inner_expr, :argument_list, ")"].as do |_,_,n,a|
      result = [Tokens::RECCALL, n]
      GrammarHelpers::gather_arguments result, a 
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

    r["(", :mod, :inner_expr, :inner_expr, ")"].as { |_,_,a,b,_| [ Tokens::MOD, a, b ] }
    
    r["(", "/", :inner_expr, :inner_expr, ")"].as { |_,_,a,b,_| [ Tokens::DIV, a, b ] }
    
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
    r[:null].as { |_| ["void"] }

    r[:quoted].as { |q| q }
    
  end

  rule(:quoted) do |r|
    r[:quote].as { |q| [Tokens::QUOTE, SXP.read(q[1..-1])] }
  end
  
  rule(:param_list) do |r|
    r[:name, :param_list].as { |n, a| ([n] + [a]) }
    r[:name].as { |n| n }
  end

  rule(:argument_list) do |r|
    r[:inner_expr].as { |d| d }
    r[:inner_expr, :argument_list].as { |n, a| ([n] + [a]) }
  end

  start(:expr)
end

