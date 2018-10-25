# frozen_string_literal: true

require 'uri'

SafeHosts = Settings.web_origin.split(',').map do |url|
  begin
    URI.parse(url.strip).hostname.to_s
  rescue StandardError
    ''
  end
end.uniq
