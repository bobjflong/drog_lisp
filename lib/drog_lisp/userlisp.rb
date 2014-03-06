
# This class encapsulates some embedded lisp code.
# This is lisp that is typically dynamically generated during a drog_lisp session

# This class can take strings or data structures, and is capable of wrapping lisp fragments
# into valid drog_lisp programs
class UserLisp

  attr_reader :program
  
  def initialize program
    if program.kind_of? String
      @program = unescape program
    else
      @program = unescape(from_data_structure program)
    end
  end

  private

  def unescape program
    program.gsub /\\"/, '"'
  end

  def from_data_structure program
    if not program.first == :Do
      return wrap_program(program).to_sxp
    end
    program.to_sxp
  end

  def wrap_program program
    [:Do, program]
  end

end

