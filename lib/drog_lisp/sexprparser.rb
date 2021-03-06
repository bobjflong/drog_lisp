
require 'thread'
require 'sxp'
require 'drog_lisp/stdlib'

class LispMacro
 
  attr_reader :name
  attr_reader :handler

  def initialize(name, &block)
    @name = name
    @handler = block
  end

  def handle ast, split, other_macros
    result = @handler.call ast
    LispPreprocessor.preprocess result, other_macros
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

  def empty?
    @macros.empty?
  end

  def +(other)
    MacroList.new(@macros + other.macros)
  end

  def apply_one_to_prog sxp_parser, prog, other_macros
    @macros.find do |m|
      LispPreprocessor.apply_macro_to_prog sxp_parser, m, prog, other_macros
    end
  end
end

module LispPreprocessor
  
  def self.preprocess prog, macros
    LispPreprocessor.apply_macros_to_prog (macros + StandardMacros.macros), prog 
  end

  def self.apply_macros_to_prog macros, prog
    sxp_parser = SexprParser.new prog
    sxp_parser.find_sexprs
    
    #each round we attempt to apply a macro
    #the sxp_parser needs to be updated if a macro is successfully applied
    while true
      once_applied = macros.apply_one_to_prog sxp_parser, prog, macros
      if once_applied
        sxp_parser = SexprParser.new prog
        sxp_parser.find_sexprs
      else
        break
      end
    end

  end

  def self.apply_macro_to_prog sxp_parser, macro, prog, other_macros
    matching_sxps = sxp_parser.sxps_matching_macro macro

    return false if matching_sxps.empty?
    
    i = matching_sxps[0]
    split = StringSplit.new prog, sxp_parser.positions[i]
    macro.handle SXP.read(sxp_parser.parsed[i]), split, other_macros
    
    return true
  end
end

# This class extracts all of the s-expressions from a drog_lisp program
# This is used for macro expansion
class SexprParser

  attr_reader :parsed
  attr_reader :positions

  def initialize text
    @raw = text
    delete_comments!

    @text = @raw.split ''
    @parsed = []
    @positions = []
  end

  def sxps_matching_macro macro
    @positions.each_with_index do |p,i|
      return [i] if get_sxp_name(@parsed[i]) == macro.name
    end
    []
  end

  def get_sxp_name sxp
    sxp.match /\([ ]*([^ ()$]+)/
    $1.strip
  end

  def find_matching_bracket i
    i = i + 1
    start = i - 1
    count = 1
    in_string = false
    
    while true
      next_val = @text[i]
      prev_val = i > 0 ? @text[i-1] : nil

      if next_val == '"' and not prev_val == '\\'
        in_string = in_string ? false : true
      end

      if next_val == ')' and not in_string

        count -= 1
        if count == 0
          raw = @raw[start..i]
          @parsed << raw
          @positions << Position.new(start, i)
          return
        end
      end

      if next_val == '(' and not in_string
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
    in_string = false

    @text.each_with_index do |v, i|
      if v == '"'
        in_string = in_string ? false : true
      end
      if v == '(' and not in_string
        find_matching_bracket i
      end
    end
    threads.each { |t| t.join }
  end

  private

  def delete_comments!
    @raw.gsub! /^[\"]*\;[^\n]*$/, ''
  end
end

class Position < Struct.new(:start, :end)
end

# Add to_cons to the array class,
# Makes metaprogramming a breeze
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


