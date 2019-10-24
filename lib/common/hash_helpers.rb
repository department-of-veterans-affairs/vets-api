# frozen_string_literal: true

module Common
  module HashHelpers
    module_function

    def deep_transform_parameters!(val, &block)
      # rails 5.1 no longer has deep_transform_keys!
      # because params are no longer inheriting from HashWithIndifferentAccess
      case val
      when Array
        val.map { |v| deep_transform_parameters!(v, &block) }
      when Hash, ActionController::Parameters
        val.keys.each do |k, v = val[k]|
          val.delete(k)
          val[yield(k)] = deep_transform_parameters!(v, &block)
        end
        val
      else
        val
      end
    end

    def deep_remove_blanks(hash)
      deep_remove_helper(hash) do |v|
        v.blank? && v != false
      end
    end

    def deep_remove_helper(hash)
      delete_if_block = proc do |_k, v|
        if v.is_a?(Hash)
          v.delete_if(&delete_if_block)
          nil
        elsif v.is_a?(Array)
          v.reject! { |i| yield(i) }
          v.each do |item|
            delete_if_block.call(nil, item)
          end

          nil
        else
          yield(v)
        end
      end

      hash.delete_if(&delete_if_block)
    end

    def deep_compact(hash)
      deep_remove_helper(hash, &:nil?)
    end
  end
end
