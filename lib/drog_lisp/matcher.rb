require 'whittle'

class Pattern < Whittle::Parser
  rule(":")
  rule("@")

  rule(:name => /[a-zA-Z]+/).as { |val| val.to_sym }

  rule(:full) do |r|
    
    r[:name, "@", :full].as { |a, _, rest| {
        a => Proc.new { |list, pointer|
          { pointer: pointer, result: list}
        }
      }.merge(rest)
    }

    r[:name, ":", :name].as { |a, _, b| { 
        a => Proc.new { |list, pointer| 
          { pointer: pointer+1, result: list[pointer + 1] }
        },
        b => Proc.new { |list, pointer| 
          {pointer: pointer + 1, result: list[pointer + 1..-1] }
        }
      }
    }

    r[:name, ":", :full].as { |a, _, rest| {
        a => Proc.new { |list, pointer|
          { pointer: pointer+1, result: list[pointer + 1] }
        }
      }.merge(rest)
    }
  end

  start(:full)
end

class Array
  define_method('drog_pattern') do |pattern, &block|
    ans = (Pattern.new).parse(pattern)
    pointer = -1
    block.call(ans.merge(ans) do |key, val|
      res = val.call(self, pointer)
      pointer = res[:pointer]
      res[:result]
    end)
  end
end

