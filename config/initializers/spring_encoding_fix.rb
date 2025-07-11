# frozen_string_literal: true

# Fix Spring encoding issues by patching the JSON module
if defined?(Spring) && defined?(Spring::JSON)
  module Spring
    module JSON
      class << self
        alias_method :original_load, :load
        
        def load(string)
          # Force UTF-8 encoding and handle encoding errors
          string = string.force_encoding('UTF-8') if string.respond_to?(:force_encoding)
          original_load(string)
        rescue Encoding::CompatibilityError, Encoding::UndefinedConversionError
          # If encoding fails, try to clean and retry
          cleaned_string = string.encode('UTF-8', invalid: :replace, undef: :replace)
          original_load(cleaned_string)
        end
      end
    end
  end
end