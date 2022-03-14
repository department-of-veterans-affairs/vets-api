# frozen_string_literal: true

module AppealsApi
  module CharacterValidation
    extend ActiveSupport::Concern

    included do
      OUTSIDE_WINDOWS_1252_PATTERN ||= /[^\u0000-\u0255]+/.freeze

      def validate_characters
        characters = request.headers.to_s + params.to_s
        characters.encode('WINDOWS-1252')
      rescue Encoding::UndefinedConversionError => e
        Rails.logger.error "#{self.class} [#{e.class}] error:#{e.message}"
        render_invalid_characters_error if characters =~ OUTSIDE_WINDOWS_1252_PATTERN
      end

      private

      def render_invalid_characters_error
        render(
          status: :unprocessable_entity,
          json: {
            errors: [
              {
                status: 422,
                detail: 'Invalid characters in headers/body.',
                meta: { pattern: OUTSIDE_WINDOWS_1252_PATTERN.inspect }
              }
            ]
          }
        )
      end
    end
  end
end
