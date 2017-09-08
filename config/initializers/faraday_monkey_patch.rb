require 'faraday_monkey_patch/options'
require 'faraday_monkey_patch/adapter/net_http_streaming'

::Faraday::Adapter.register_middleware File.expand_path('lib/faraday_monkey_patch/adapter'),
  net_http_streaming: [:NetHttpStreaming, 'net_http_streaming']
