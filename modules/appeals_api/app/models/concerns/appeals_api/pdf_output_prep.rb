# frozen_string_literal: true

module AppealsApi
  module PdfOutputPrep
    extend ActiveSupport::Concern

    included do
      def pdf_output_prep
        clear_memoized_values
        auth_headers.deep_transform_values! { |v| normalize_characters v }
        form_data.deep_transform_values! { |v| normalize_characters v }
      end

      private

      # Removes characters that the default PDF output font cannot handle while keeping the original encoding
      # Avoids Prawn::Errors::IncompatibleStringEncoding exceptions
      def normalize_characters(val)
        return val unless val.respond_to?(:encode)

        orig_encoding = val.encoding
        val.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '')
           .encode(orig_encoding, 'Windows-1252')
      end

      def clear_memoized_values
        # No-Op - override in your models as necessary
      end
    end
  end
end
