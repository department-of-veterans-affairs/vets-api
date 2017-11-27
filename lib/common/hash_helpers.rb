module Common
  module HashHelpers
    module_function

    def deep_compact(hash)
      delete_if_block = Proc.new do |k, v|
        v.kind_of?(Hash) ? (v.delete_if(&delete_if_block); nil) : v.nil?
      end

      hash.delete_if(&delete_if_block)
    end
  end
end
