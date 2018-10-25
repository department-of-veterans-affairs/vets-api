require 'uri'

SafeHosts = Settings.web_origin.strip.split(',').map { |url| URI.parse(url).hostname.to_s rescue '' }.uniq
