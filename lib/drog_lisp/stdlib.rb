
# This standard library comprises
# 1. useful drog_lisp listings that are included before every program
# 2. useful macros used to preprocess every program

class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  def unflat_send msg, *args
    self.send msg, args
  end
end

module StandardFunctions
  def self.map
    %Q(
      (Func map f x)
        (Do
          (Let list x)
          (If (Send "blank?" list)
            (Send :new :Array)
            (Cons (Call f (Car list)) (Call map f (Cdr list)))))
    )
  end

  def self.fold
    %Q(
      (Func fold f acc x)
        (Do
          (Let list x)
          ;(Send :pry :binding)
          (If (Send "blank?" list)
            acc
            (Call fold f (Call f acc (Car list)) (Cdr x))))
    )
  end

  def self.filter
    %Q(
      (Func filter f x)
        (Do
          (Let list x)

          (If (Send "blank?" list)
            (Send :new :Array)
            (If (Call f (Car list))
              (Cons (Car list) (Call filter f (Cdr list)))
              (Call filter f (Cdr list)))))
    )
  end
  
  # Like Cons but without merging
  def self.concat
    %Q(
      (Func concat x y)
        (Do
          (If (= "Array" (Send :to_s (Send :class x)))
            (Let left x)
            (Let left (Send (Cons :push x) (Send :new :Array))))
          (Send (Cons :unflat_send (Cons "<<" y)) left)
          left)
    )
  end
  
  def self.listing
    "(Do " + ([StandardFunctions.concat, StandardFunctions.fold, StandardFunctions.filter, StandardFunctions.map].join " ") + ")"
  end
end

module StandardMacros
  def self.backtick
    LispMacro.new '`' do |ast|
      #to_cons currently defined in sexprparser.rb
      ast.drop(1).to_cons
    end
  end

  def self.load
    LispMacro.new 'load' do |ast|
      file = ast[1]
      %Q(
        (Let directory (Send (Cons :+ "/") DIR))
        (Let absolute (Send (Cons :+ "#{file}") directory))
        (Evaluate (Send (Cons :read absolute) :File))
      )
    end
  end

  def self.quote
    LispMacro.new "'" do |ast|
      "\n(!\n !" + ast[1].to_sxp + "\n!)\n" 
    end
  end
  
  # wrap a simple function body into an anon function definition
  # (+ 1 2)
  # => (Func _ void) (Do (+ 1 2))
  def self.fwrap
    LispMacro.new 'fwrap' do |ast|
      [:Func, :_, :void].to_sxp + [:Do, ast[1]].to_sxp
    end
  end

  def self.quick_call
    LispMacro.new '#' do |ast|
      ast[0] = :Call
      ast.to_sxp
    end
  end

  # Sequence a series of messages to be sent to an origin object
  # (send_all "to_s" (`(2013 3 4)) :Date)
  # => (Send "to_s" (Send (Cons :new (Cons 2013 (Cons 3 4))) :Date))
  # => 2013-03-04
  def self.send_all
    LispMacro.new 'send_all' do |ast|
      origin = ast.pop
      messages = ast.drop 1

      unless messages.empty?
        StandardMacros.deflatten(messages, :Send, origin).to_sxp
      else
        String.new
      end
    end
  end

  #alias for send_all
  def self.send_all_arrow
    LispMacro.new '->' do |ast|
      ast[0] = :send_all
      ast.to_sxp
    end
  end

  # TODO
  # this has been copypasted from brig
  # it's basic, but write a test
  def self.cat
    LispMacro.new 'cat' do |ast|
      left = ast[1].to_sxp
      right = ast[2].to_sxp
      """(Send (Cons :+ #{right}) #{left})"""
    end
  end
  
  #Alias for Send
  def self.dot
    LispMacro.new '.' do |ast|
      [:Send, ast[1], ast[2]].to_sxp
    end
  end

  def self.lambda
    LispMacro.new 'lambda' do |ast|
      #y ~(x) (Do ... )
      ast = ast.drop 1
      #y ~(x)
      
      body = ast.pop
      body = [:Do, body] unless body.first == :Do
      
      #rewrite the prototype as a Func
      proto = ast.unshift :_
      proto = proto.unshift :Func
      proto.to_sxp + body.to_sxp
    end
  end

  def self.let_many
    LispMacro.new 'LetMany' do |ast|
      res = ""
      ast.drop(1).each do |let|
        res += [:Let, let.first, let.drop(1).first].to_sxp
      end
      res
    end
  end

  def self.macros
    MacroList.new [StandardMacros.dot, StandardMacros.cat, StandardMacros.fwrap, StandardMacros.quote,
    StandardMacros.backtick, StandardMacros.send_all, StandardMacros.lambda, StandardMacros.send_all_arrow, StandardMacros.load, StandardMacros.quick_call, StandardMacros.let_many]
  end

  # Nest a list of items
  # self.deflatten [:one, :two], :Op, :three
  # => [:Op, :one, [:Op, :two :three]]
  def self.deflatten list, prefix, final
    next_value = list.shift
    if list.empty?
      [prefix, next_value, final]
    else
      [prefix, next_value, StandardMacros.deflatten(list, prefix, final)]
    end
  end

end
