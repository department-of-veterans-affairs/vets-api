module Faraday
  class NewRequestOptions < Options.new(:params_encoder, :proxy, :bind,
    :timeout, :open_timeout, :boundary, :oauth, :context, :on_data)

    def []=(key, value)
      if key && key.to_sym == :proxy
        super(key, value ? ProxyOptions.from(value) : nil)
      else
        super(key, value)
      end
    end

    def stream_response?
      on_data.is_a?(Proc)
    end
  end

  class ConnectionOptions
    options request: NewRequestOptions, ssl: SSLOptions
  end

  class Env
    options request: NewRequestOptions, request_headers: Utils::Headers, response_headers: Utils::Headers
  end
end
