# frozen_string_literal: true

module HealthQuest
  module Lighthouse
    ##
    # An object responsible for fetching and building access_tokens
    # from the Lighthouse for the Lighthouse::Session object.
    #
    # @!attribute api
    #   @return [String]
    # @!attribute user
    #   @return [User]
    # @!attribute request
    #   @return [Lighthouse::Request]
    # @!attribute claims_token
    #   @return [Lighthouse::ClaimsToken]
    # @!attribute access_token
    #   @return [String]
    # @!attribute decoded_token
    #   @return [Hash]
    class Token
      ACCESS_TOKEN = 'access_token'
      EXPIRATION = 'exp'
      SCOPES_DELIMITER = ' '

      attr_reader :api, :user, :request, :claims_token
      attr_accessor :access_token, :decoded_token

      ##
      # Builds a Lighthouse::Token instance from a user
      #
      # @param user [User] the current user
      # @param api [String] the Lighthouse api
      # @return [Lighthouse::Token] an instance of this class
      #
      def self.build(user:, api:)
        new(user:, api:)
      end

      def initialize(opts)
        @api = opts[:api]
        @user = opts[:user]
        @request = Request.build
        @claims_token = ClaimsToken.build(api:).sign_assertion
      end

      ##
      # Return a token instance that was built using the access_token data
      # from the response obtained by calling the Lighthouse with a certain
      # set of parameters
      #
      # @return [Lighthouse::Token]
      #
      def fetch
        response = request.post(api_paths[api], post_params)

        self.access_token = Oj.load(response.body).fetch(ACCESS_TOKEN)
        self.decoded_token = JWT.decode(access_token, nil, false).first
        self
      end

      ##
      # Return a integer representing the time the Token instance was created at
      #
      # @return [Integer]
      #
      def created_at
        @created_at ||= Time.zone.now.utc.to_i
      end

      ##
      # Return the duration for which the saved redis session is valid
      #
      # @return [Integer]
      #
      def ttl_duration
        exp = decoded_token.fetch(EXPIRATION)

        Time.zone.at(exp).utc.to_i - Time.zone.now.utc.to_i - 5
      end

      ##
      # Build the encoded form string from a hash of parameters
      #
      # @return [String]
      #
      def post_params
        hash = {
          grant_type: lighthouse.grant_type,
          client_assertion_type: lighthouse.client_assertion_type,
          client_assertion: claims_token,
          scope: scopes[api].join(SCOPES_DELIMITER),
          launch: base64_encoded_launch
        }

        URI.encode_www_form(hash)
      end

      ##
      # Hash for selecting the access token path based on the api
      #
      # @return [Hash]
      #
      def api_paths
        { 'pgd_api' => lighthouse.pgd_token_path, 'health_api' => lighthouse.health_token_path }
      end

      ##
      # Hash for selecting the request scopes based on the api
      #
      # @return [Hash]
      #
      def scopes
        { 'pgd_api' => lighthouse.pgd_api_scopes, 'health_api' => lighthouse.health_api_scopes }
      end

      ##
      # Base64 encoded object containing the user's ICN as the value
      #
      # @return [String]
      #
      def base64_encoded_launch
        json_obj = Oj.dump({ patient: user&.icn })

        Base64.encode64(json_obj)
      end

      private

      def lighthouse
        Settings.hqva_mobile.lighthouse
      end
    end
  end
end
