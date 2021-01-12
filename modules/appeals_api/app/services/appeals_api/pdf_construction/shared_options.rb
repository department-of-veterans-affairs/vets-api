module AppealsApi
  module PdfContruction
    module SharedOptions
      def header_field_as_string(key)
        auth_headers&.dig(key).to_s.strip
      end
    end
  end
end
