module Enumerable
  def count_by(&block)
    list = group_by(&block)
      .map { |key, items| [key, items.count] }
      .sort_by(&:last)
      
    Hash[list]
  end
end
