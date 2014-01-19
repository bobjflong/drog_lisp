require 'drog_lisp'
require 'drog_lisp/sexprparser'

# difference between _ and _
diff = LispMacro.new 'difference' do |ast|
  left = ast[2].to_sxp
  right = ast[4].to_sxp
  """(Send :abs (- #{left} #{right}))"""
end

empty = LispMacro.new 'empty' do |ast|
  """(Send 'nil?' #{ast[1].to_sxp})"""
end

until_macro = LispMacro.new 'until' do |ast|
  receiver = ast[1].to_sxp
  signal   = ast[3].to_sxp
  """(LoopUntil (#{signal} #{receiver})
        #{ast[4].to_sxp}
     )
  """
end

small_enough = LispMacro.new 'small-enough' do |ast|
  """(< #{ast[1].to_sxp} (/ 1 10))"""
end

equal = LispMacro.new 'equal?' do |ast|
  """(= #{ast[1].to_sxp} #{ast[2].to_sxp})"""
end

prog = File.read "der.drog"
LispPreprocessor.preprocess prog, MacroList.new([diff, empty, until_macro, small_enough,equal])
puts prog
LispMachine.run prog
