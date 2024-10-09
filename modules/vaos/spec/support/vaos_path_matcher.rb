# frozen_string_literal: true

VCR.configure do |c|
  c.register_request_matcher :path do |request1, request2|
    request1.parsed_uri.path.sub('vaos-alt', 'vaos') == request2.parsed_uri.path
  end
end
