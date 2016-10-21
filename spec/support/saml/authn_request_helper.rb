# frozen_string_literal: true
module SAML
  # The responsibility of this class is to decode+inflate the SAML AuthnRequest that
  # gets generated for the purpose of testing.  Using this class a tester can see
  # exactly what kind of AuthNRequest was generated.
  class AuthnRequestHelper
    # from ruby-saml source code
    BASE64_FORMAT = %r(\A[A-Za-z0-9+/]{4}*[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=?\Z)

    def initialize(url)
      @authn_request = url
      @authn_request.slice!('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
      @authn_request = URI.unescape(@authn_request)

      @authn_request = decode_raw_saml(@authn_request)
    end

    def loa1?
      @authn_request.include?("<saml:AuthnContextClassRef>#{LOA::MAPPING.invert[1]}")
    end

    def loa2?
      @authn_request.include?("<saml:AuthnContextClassRef>#{LOA::MAPPING.invert[2]}")
    end

    def loa3?
      @authn_request.include?("<saml:AuthnContextClassRef>#{LOA::MAPPING.invert[3]}")
    end

    private

    ### These methods were pulled directly from the ruby-saml source code
    ### https://github.com/onelogin/ruby-saml/blob/master/lib/onelogin/ruby-saml/authrequest.rb
    def decode_raw_saml(saml)
      return saml unless base64_encoded?(saml)

      decoded = decode(saml)
      begin
        inflate(decoded)
      rescue
        decoded
      end
    end

    def decode(string)
      Base64.decode64(string)
    end

    def base64_encoded?(string)
      !(!string.gsub(/[\r\n]|\\r|\\n/, '').match(BASE64_FORMAT))
    end

    def inflate(deflated)
      Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(deflated)
    end
  end
end
