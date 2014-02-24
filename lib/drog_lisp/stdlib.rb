
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

  def self.macros
    MacroList.new [StandardMacros.backtick]
  end
end
