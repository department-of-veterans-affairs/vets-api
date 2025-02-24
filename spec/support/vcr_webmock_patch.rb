# frozen_string_literal: true

# Monkey patching the request_headers_for method to override the deletion of the Host header when Excon is present
# Original code: https://github.com/vcr/vcr/blob/5a1394891f72c8cd9286d15bf57ec9aa4c37af3e/lib/vcr/library_hooks/webmock.rb#L53-L69.
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
