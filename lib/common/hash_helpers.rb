# frozen_string_literal: true

module Common
  module HashHelpers
    module_function

    def deep_compact(hash)
      delete_if_block = proc do |_k, v|
        if v.is_a?(Hash)
          v.delete_if(&delete_if_block)
          nil
        else
          v.nil?
        end
      end

      hash.delete_if(&delete_if_block)
    end
  end
end
