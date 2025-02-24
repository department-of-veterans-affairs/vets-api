# frozen_string_literal: true

module VCR
  class LibraryHooks
    module WebMock
      module Helpers
        if defined?(::Excon)
          def request_headers_for(webmock_request)
            webmock_request.headers
          end
        end
      end
    end
  end
end
