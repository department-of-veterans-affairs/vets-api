# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module MimeTypes
        GIF_REGEX = /\.gif$/i
        JPEG_REGEX = /\.jpe?g/i
        PNG_REGEX = /\.png$/i

        private

        def mime_type(path)
          case path
          when GIF_REGEX
            'image/gif'
          when JPEG_REGEX
            'image/jpeg'
          when PNG_REGEX
            'image/png'
          else
            'application/octet-stream'
          end
        end
      end
    end
  end
end
