
#Special case with keyword :Do
#:Do -cons with-
#[:+, :x, :y]
# => [:Do, [:+, :x, :y]]
# ie. Should not be merged into one list
# makes writing drog programs in drog a little easier

class ConsPair
  
  def initialize left, right
    @left, @right = left, right
  end
  
  def resolve
    
    return @left if not @right
    
    return merge_do_keyword_with_list(@left, @right) if @left == :Do
    
    return merge_normal @left, @right
  
  end
  
  private

  def is_cmpd branch
    (branch.kind_of? Array and branch.length > 1 and branch[0].kind_of? Array)
  end

  def is_not_cmpd branch
    not is_cmpd(branch)
  end

  def wrap_unless_cmpd branch
    return [] unless branch
    return branch if is_cmpd(branch)
    [branch]
  end
  
  def merge_normal left, right
    if left.kind_of? Array
      [left] + wrap_unless_cmpd(right)
    else
      [left,right].flatten 1
    end
  end

  def merge_do_keyword_with_list left, right
    if is_not_cmpd right
      [left, right] 
    else
      [left, right].flatten 1
    end
  end
end

