# frozen_string_literal: true

module Idp
  class JsonDiff
    def initialize(lhs:, rhs:)
      @lhs = normalize(lhs)
      @rhs = normalize(rhs)
    end

    def call
      differences = []
      compare(lhs, rhs, differences, path: nil)

      {
        is_different: differences.any?,
        diff: differences
      }
    end

    private

    attr_reader :lhs, :rhs

    def compare(lhs_value, rhs_value, differences, path:)
      if lhs_value.is_a?(Hash) && rhs_value.is_a?(Hash)
        compare_hashes(lhs_value, rhs_value, differences, path:)
      elsif lhs_value.is_a?(Array) && rhs_value.is_a?(Array)
        compare_arrays(lhs_value, rhs_value, differences, path:)
      elsif lhs_value != rhs_value
        add_difference(differences, path:, lhs_value:, rhs_value:)
      end
    end

    def compare_hashes(lhs_hash, rhs_hash, differences, path:)
      keys = (lhs_hash.keys + rhs_hash.keys).uniq.sort

      keys.each do |key|
        lhs_has_key = lhs_hash.key?(key)
        rhs_has_key = rhs_hash.key?(key)
        key_path = append_key(path, key)

        unless lhs_has_key && rhs_has_key
          add_difference(
            differences,
            path: key_path,
            lhs_value: lhs_has_key ? lhs_hash[key] : nil,
            rhs_value: rhs_has_key ? rhs_hash[key] : nil
          )
          next
        end

        compare(lhs_hash[key], rhs_hash[key], differences, path: key_path)
      end
    end

    def compare_arrays(lhs_array, rhs_array, differences, path:)
      max_length = [lhs_array.length, rhs_array.length].max

      max_length.times do |index|
        lhs_has_index = index < lhs_array.length
        rhs_has_index = index < rhs_array.length
        index_path = append_index(path, index)

        unless lhs_has_index && rhs_has_index
          add_difference(
            differences,
            path: index_path,
            lhs_value: lhs_has_index ? lhs_array[index] : nil,
            rhs_value: rhs_has_index ? rhs_array[index] : nil
          )
          next
        end

        compare(lhs_array[index], rhs_array[index], differences, path: index_path)
      end
    end

    def add_difference(differences, path:, lhs_value:, rhs_value:)
      key = path.presence || 'value'
      differences << {
        key => {
          lhs: lhs_value,
          rhs: rhs_value,
          is_different: true
        }
      }
    end

    def append_key(path, key)
      return key.to_s if path.blank?

      "#{path}.#{key}"
    end

    def append_index(path, index)
      return "[#{index}]" if path.blank?

      "#{path}[#{index}]"
    end

    def normalize(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, entry), normalized|
          normalized[key.to_s] = normalize(entry)
        end
      when Array
        value.map { |entry| normalize(entry) }
      else
        value
      end
    end
  end
end
