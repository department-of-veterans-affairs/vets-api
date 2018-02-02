# frozen_string_literal: true

# Monkey-patch Faraday to support SOCKS proxy so we can use
# aws jumpbox / EVSS AWS service
# source - https://stackoverflow.com/a/36534327
if Settings.faraday_socks_proxy.enabled
  class Faraday::Adapter::NetHttp
    def net_http_connection(env)
      proxy = env[:request][:proxy]
      if proxy
        if proxy[:socks]
          Net::HTTP::SOCKSProxy(proxy[:uri].host, proxy[:uri].port)
        else
          Net::HTTP::Proxy(proxy[:uri].host, proxy[:uri].port, proxy[:uri].user, proxy[:uri].password)
        end
      else
        Net::HTTP
      end.new(env[:url].host, env[:url].port)
    end
  end
end
