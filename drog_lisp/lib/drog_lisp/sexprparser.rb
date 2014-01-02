
require 'thread'
require 'sxp'

class Array
  def to_cons
    res = ""
    self.each do |v|
      if v.kind_of? Array
        res += "(Cons #{v.to_cons}"
      else
        res += "(Cons #{v.to_sxp}"
      end
    end
    res += " null "
    res += (")" * self.length)
  end
end

class LispMacro
 
  attr_reader :name
  attr_reader :handler

  def initialize(name, &block)
    @name = name
    @handler = block
  end

  def handle ast, split
    result = @handler.call ast
    split.replace_with result
  end
end

class StringSplit < Struct.new(:string, :position)
  def replace_with str
    string[position.start..position.end] = str
  end
end

class MacroList
  attr_reader :macros

  def initialize(macros)
    @macros = macros
  end

  def matching name
    MacroList.new(@macros.find_all { |m| m.name == name.to_s })
  end

  def call ast, split
    @macros.each { |m| m.handle ast, split }
  end
end

module LispPreprocessor
  
  def self.preprocess prog, macros
    possible_macro_extractor = SexprParser.new prog
    possible_macro_extractor.find_sexprs
    possible_macro_extractor.parsed.each_with_index do |v, i|
      parsed = SXP.read v
      matching_macros = macros.matching parsed[0]
      split = StringSplit.new prog, possible_macro_extractor.positions[i]
      matching_macros.call parsed, split
    end
  end
end

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
    @mutex = Mutex.new
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
          @mutex.synchronize do
            @parsed << @raw[start..i]
            @positions << Position.new(start, i)
          end
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
    threads = []
    @text.each_with_index do |v, i|
      if v == '('
        threads << Thread.new do
          find_matching_bracket i
        end
      end
    end
    threads.each { |t| t.join }
  end
end

class Position < Struct.new(:start, :end)
end
