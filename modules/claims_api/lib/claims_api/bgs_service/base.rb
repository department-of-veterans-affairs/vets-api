# frozen_string_literal: true

require 'savon'
require 'nokogiri'
require 'httpclient'

module ClaimsApi
  module LocalBGS
    # This class is a base-class from which most Web Services will inherit.
    # This contains the basics of how to talk with the BGS SOAP API, in
    # particular, the VA's custom SOAP headers for auditing. As a bonus, it's
    # also aware of the BGS's URL patterns, making it easy to define new
    # web services as needed using some light reflection.
    class Base
      # Base-class constructor. This sets up some instance instance variables
      # for use later -- such as the client's IP, and who we are.
      # Special notes:
      # -`forward_proxy_url`, if provided, will funnel all requests to the provided
      # url instead of directly to BGS, and add the destination hostname
      # in the HTTP headers under "Host".
      # -`log` will enable `savon` logging.

      # `jumpbox_url` is to be able to test through the jumpbox.
      # in order to use this, add the following line to your jumpbox configuration in ~/.ssh/config
      # LocalForward [local port number] beplinktest.vba.va.gov:80
      # and when initializing the client, set the jumpbox_url = 'http://127.0.0.1:[local port number]'

      attr_accessor :mock_responses

      def initialize(application:, env:, client_ip:, client_station_id:, # rubocop:disable Metrics/ParameterLists
                     client_username:, forward_proxy_url: nil, jumpbox_url: nil, log: false,
                     logger: nil, ssl_cert_file: nil, ssl_cert_key_file: nil, ssl_ca_cert: nil,
                     external_uid: nil, external_key: nil, mock_responses: false, ssl_verify_mode: 'peer')
        @application = application
        @client_ip = client_ip
        @client_station_id = client_station_id
        @client_username = client_username
        @log = log
        @logger = logger
        @env = env
        @forward_proxy_url = forward_proxy_url
        @jumpbox_url = jumpbox_url
        @ssl_cert_file = ssl_cert_file
        @ssl_cert_key_file = ssl_cert_key_file
        @ssl_ca_cert = ssl_ca_cert
        @service_name = self.class.name.split('::').last
        @external_uid = external_uid
        @external_key = external_key
        @mock_responses = mock_responses
        @ssl_verify_mode = ssl_verify_mode
      end

      def self.service_name
        name = self.name.split('::').last.downcase
        name = name[0..-11] if name.end_with? 'webservice'
        "#{name}s"
      end

      def healthy?
        client.operations.any?
      rescue
        false
      end

      def namespace
        nil
      end

      private

      def validate_required_keys(required_keys, provided_hash, call)
        required_keys.each do |key|
          raise(ArgumentError, "#{key} is a required key in #{call}") unless provided_hash.key?(key)
          raise(ArgumentError, "#{key} cannot be empty or nil") if provided_hash[key].blank?
        end
      end

      def https?
        @ssl_cert_file && @ssl_cert_key_file
      end

      def wsdl
        "#{endpoint}?WSDL"
      end

      def endpoint
        "#{base_url}/#{bean_name}/#{@service_name}"
      end

      def base_url
        # Proxy url or jumpbox url should include protocol, domain, and port.
        return @forward_proxy_url if @forward_proxy_url
        return @jumpbox_url if @jumpbox_url

        "#{https? ? 'https' : 'http'}://#{domain}"
      end

      def domain
        "#{@env}.vba.va.gov"
      end

      def bean_name
        "#{@service_name}Bean"
      end

      # Return the VA SOAP audit header. Given the instance variables sitting
      # off the instance, we will go ahead and construct the SOAP Header that
      # we want to send along with requests -- this is mostly used for auditing
      # who is doing what, rather than securing the communications between BGS
      # and us.
      #
      # Audit logs are great. Let's do more of them.
      def header
        # Stock XML structure {{{
        header = Nokogiri::XML::DocumentFragment.parse <<~EOXML
          <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
            <wsse:UsernameToken>
              <wsse:Username></wsse:Username>
            </wsse:UsernameToken>
            <vaws:VaServiceHeaders xmlns:vaws="http://vbawebservices.vba.va.gov/vawss">
              <vaws:CLIENT_MACHINE></vaws:CLIENT_MACHINE>
              <vaws:STN_ID></vaws:STN_ID>
              <vaws:applicationName></vaws:applicationName>
              <vaws:ExternalUid ></vaws:ExternalUid>
              <vaws:ExternalKey></vaws:ExternalKey>
            </vaws:VaServiceHeaders>
          </wsse:Security>
        EOXML
        # }}}

        { Username: @client_username, CLIENT_MACHINE: @client_ip,
          STN_ID: @client_station_id, applicationName: @application,
          ExternalUid: @external_uid, ExternalKey: @external_key }.each do |k, v|
          header.xpath(".//*[local-name()='#{k}']")[0].content = v
        end
        header
      end

      # Return a `savon` client all configured like we like it. Optionally,
      # logging can be enabled by passing `log: true` to the constructor
      # of any of the services.
      def client
        # Tack on the destination header if we're sending all requests
        # to a forward proxy.
        headers = {}
        headers['Host'] = domain if @forward_proxy_url

        options = {
          wsdl: wsdl,
          soap_header: header,
          log: @log,
          logger: @logger,
          ssl_cert_key_file: @ssl_cert_key_file,
          headers: headers,
          ssl_cert_file: @ssl_cert_file,
          ssl_ca_cert_file: @ssl_ca_cert,
          open_timeout: 10, # in seconds
          read_timeout: 5, # in seconds
          convert_request_keys_to: :none,
          ssl_verify_mode: @ssl_verify_mode.to_sym
        }
        options.merge!(namespace) if namespace
        options[:endpoint] = endpoint unless @forward_proxy_url.nil?
        @client ||= Savon.client(options)
      end

      # Proxy to call a method on our web service.
      def request(method, message = nil, identifier = nil)
        if mock_responses
          raise 'No identifier for mock response' if identifier.nil?

          file_path = BGS.configuration.mock_response_location
          file_path += "/#{@service_name.underscore}/#{method}/#{identifier}.json"
          Struct.new(:body).new(JSON.parse(File.read(file_path)).with_indifferent_access)
        else
          client.call(method, message: message)
        end
      rescue HTTPClient::ConnectTimeoutError, HTTPClient::ReceiveTimeoutError, Errno::ETIMEDOUT => _e
        # re-try once assuming this was a server-side hiccup
        sleep 1
        client.call(method, message: message)
      rescue Savon::SOAPFault => e
        handle_request_error(e)
      rescue Errno::ENOENT => e
        Rails.logger.debug e
      end

      def handle_request_error(error)
        message = error.to_hash[:fault][:detail][:share_exception][:message]
        code = error.http.code

        raise ClaimsApi::LocalBGS::ShareError.new(message, code)
      # If any of the elements in this path are undefined, we will raise a NoMethodError.
      # Default to sending the original Savon::SOAPFault (or ClaimsApi::LocalBGS::PublicError) in this case.
      rescue NoMethodError
        # Expect error string to look something like the following:
        # Savon::SOAPFault: (S:Client) ID: {{UUID}}: Logon ID {{CSS_ID}} Not Found
        # Only extract the final clause of that error message for the public error.
        #
        # rubocop:disable Layout/LineLength
        raise(ClaimsApi::LocalBGS::PublicError, "#{Regexp.last_match(1)} in the Benefits Gateway Service (BGS). Contact your ISO if you need assistance gaining access to BGS.") if error.to_s =~ /(Logon ID .* Not Found)/

        # rubocop:enable Layout/LineLength
        raise error
      end
    end
  end
end
# vim: foldmethod=marker
