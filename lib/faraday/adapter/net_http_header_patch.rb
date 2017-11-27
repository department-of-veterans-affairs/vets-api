# frozen_string_literal: true
require 'faraday'
require_relative 'http'

module Faraday
  class Adapter
    class NetHttpHeaderPatch < Faraday::Adapter::NetHttp
      def net_http_connection(env)
        if proxy == env[:request][:proxy]
          Faraday::Adapter::HTTP::Proxy(proxy[:uri].host, proxy[:uri].port, proxy[:user], proxy[:password])
        else
          Faraday::Adapter::HTTP
        end.new(env[:url].host, env[:url].port || (env[:url].scheme == 'https' ? 443 : 80))
      end
    end
  end
end
