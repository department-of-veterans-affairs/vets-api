# frozen_string_literal: true

module IvcChampva
  class FieldTransliterator
    def self.transliterate_all!(data, options = {})
      new(options).transliterate_all!(data)
    end

    def initialize(options = {})
      @field_patterns = options[:field_patterns] || []
      @only_keys = options[:only_keys]
      @skip_keys = Set.new(options[:skip_keys] || [])
      @max_length = options[:max_length] || 50
      # Only allow letters (a-z, A-Z), digits (0-9), spaces, hyphens, forward slashes, and whitespace characters.
      # All other characters will be removed from the string. This is to ensure that only safe, printable characters
      # are retained in the output, as required by business rules for field sanitization.
      @char_filter = options[:char_filter] || %r{[^a-zA-Z\-/\s\d]}
    end

    def transliterate_all!(data, current_path = [])
      case data
      when Hash
        data.each do |key, value|
          new_path = current_path + [key]

          if value.is_a?(String) && should_transliterate_field?(key)
            data[key] = transliterate_string(value)
          else
            transliterate_all!(value, new_path)
          end
        end
      when Array
        data.each_with_index do |item, index|
          transliterate_all!(item, current_path + [index])
        end
      end

      data
    end

    private

    def should_transliterate_field?(key)
      key_str = key.to_s

      # Skip if in skip_keys
      return false if @skip_keys.include?(key_str) || @skip_keys.include?(key.to_sym)

      # If only_keys is specified, only process those keys
      if @only_keys
        only_keys_set = Set.new(@only_keys.map(&:to_s))
        return false unless only_keys_set.include?(key_str)
      end

      # If field_patterns is specified, match against patterns
      return @field_patterns.any? { |pattern| key_str.downcase.match?(pattern) } if @field_patterns.any?

      # Default: transliterate all string fields if no restrictions
      true
    end

    def transliterate_string(string)
      return string if string.blank?

      # Preserve actual newlines by temporarily replacing them
      temp_string = string.gsub("\n", 'NEWLINEPLACEHOLDER')
      result = I18n.transliterate(temp_string)
                   .gsub(@char_filter, '')
                   .gsub('NEWLINEPLACEHOLDER', "\n")

      # For strings with newlines, don't strip to preserve formatting
      if string.include?("\n")
        result.first(@max_length)
      else
        result.strip.first(@max_length)
      end
    end
  end
end
