# array extensions
module ArrayExtensions
  refine Array do
    def delete_one(elem)
      offset = index(elem)
      return unless offset
      delete_at(offset)
    end

    def enumerate
      each_with_index.to_a
    end

    def second
      self[1]
    end
  end
end
