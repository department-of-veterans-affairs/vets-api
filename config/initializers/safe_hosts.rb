# frozen_string_literal: true

require 'uri'

SafeHosts = Settings.web_origin.strip.split(',').map do |url|
  begin
    URI.parse(url).hostname.to_s
  rescue StandardError
    ''
  end
end.uniq
