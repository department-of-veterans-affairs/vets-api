# frozen_string_literal: true

module AppealsApi
  module CharacterUtilities
    extend ActiveSupport::Concern

    included do
      def transliterate_for_centralmail(str)
        I18n.transliterate(str.to_s).gsub(/[^a-zA-Z\-\s]/, '').strip.first(50)
      end
    end
  end
end
