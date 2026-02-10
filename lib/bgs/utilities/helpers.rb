# frozen_string_literal: true

module BGS
  module Utilities
    module Helpers
      def normalize_composite_characters(str)
        # NFKD decomposes composite characters (e.g. ü, ñ) into their individual components, and here, `gsub`
        # removes any non-ASCII components (e.g. ü -> u; ñ -> n).
        str&.unicode_normalize(:nfkd)&.gsub(/[^\p{ASCII}]|[`!*%&@^]/, '')
      end

      def remove_special_characters_from_name(name)
        # Interestingly, BGS permits names with forward slashes and hyphens, but not apostrophes.
        name&.gsub(%r{[^a-zA-Z\s/-]}, '')
      end
    end
  end
end
