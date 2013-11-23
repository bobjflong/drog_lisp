
# This class extracts all of the s-expressions from a drog_lisp program
# This is used for macro expansion
class SexprParser

  attr_reader :parsed
  attr_reader :positions

  def initialize text
    @text = text.split ''
    @raw = text
    @parsed = []
    @positions = []
  end

  def find_matching_bracket i
    i = i + 1
    start = i - 1
    count = 1
    while true
      next_val = @text[i]
      if next_val == ')'

        count -= 1
        if count == 0
          @parsed << @raw[start.. i]
          @positions << Position.new(start, i)
          return
        end
      end

      if next_val == '('
        count += 1
      end
      
      if count < 0
        throw :unmatched_right_bracket
        return
      end

      if not next_val
        if count != 0
          throw :unmatched_left_bracket
          return
        end
        return
      end
      i+= 1
    end
  end

  def find_sexprs
    @text.each_with_index do |v, i|
      if v == '('
        find_matching_bracket i
      end
    end
  end
end

class Position < Struct.new(:start, :end)
end
