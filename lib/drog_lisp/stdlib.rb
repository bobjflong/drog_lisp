
# This standard library comprises
# 1. useful drog_lisp listings that are included before every program
# 2. useful macros used to preprocess every program

class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end
end

module StandardFunctions
  def self.map
    %Q(
      (Func map f x)
        (Do
          (Let list x)
          (If (Send "blank?" list)
            (empty-list)
            (Cons (Call f (Car list)) (Call map f (Cdr list)))
          )
        )
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
              (Call filter f (Cdr list))
            )
          )
        )
    )
  end

  def self.listing
    "(Do " + ([StandardFunctions.filter, StandardFunctions.map].join " ") + ")"
  end
end

module StandardMacros
  def self.backtick
    LispMacro.new '`' do |ast|
      #to_cons currently defined in sexprparser.rb
      ast.drop(1).to_cons
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

  # Sequence a series of messages to be sent to an origin object
  # (send_all "to_s" (`(2013 3 4)) :Date)
  # => (Send "to_s" (Send (Cons :new (Cons 2013 (Cons 3 4))) :Date))
  # => 2013-03-04
  def self.send_all
    LispMacro.new 'send_all' do |ast|
      origin = ast.pop
      messages = ast.drop 1

      #binding.pry
      unless messages.empty?
        StandardMacros.deflatten(messages, :Send, origin).to_sxp
      else
        String.new
      end
    end
  end

  def self.macros
    MacroList.new [StandardMacros.fwrap, StandardMacros.backtick, StandardMacros.send_all]
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
