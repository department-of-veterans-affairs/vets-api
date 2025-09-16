# frozen_string_literal: true

module VANotify
  class CallbackSignatureGenerator
    def self.call(payload, api_key)
      parsed_payload = JSON.parse(payload)

      encoded = urlencode_like_python(parsed_payload)

      OpenSSL::HMAC.hexdigest('SHA256', api_key, encoded)
    end

    def self.urlencode_like_python(hash)
      pairs = []
      hash.each do |k, v|
        pairs << [k.to_s, python_normalization(v)]
      end
      URI.encode_www_form(pairs)
    end

    def self.python_normalization(value)
      case value
      when true then 'True'
      when false then 'False'
      when nil then 'None'
      else
        value.to_s
      end
    end
  end
end
