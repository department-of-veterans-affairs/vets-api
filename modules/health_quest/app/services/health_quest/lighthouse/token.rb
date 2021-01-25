# frozen_string_literal: true

module HealthQuest
  module Lighthouse
    ##
    # An object responsible for fetching and building access_tokens
    # from the Lighthouse for the Lighthouse::Session object.
    #
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
      attr_reader :user, :request, :claims_token
      attr_accessor :access_token, :decoded_token

      ##
      # Builds a Lighthouse::Token instance from a user
      #
      # @param user [User] the current user
      #
      # @return [Lighthouse::Token] an instance of this class
      #
      def self.build(user:)
        new(user)
      end

      def initialize(user)
        @user = user
        @request = Request.build
        @claims_token = ClaimsToken.build.sign_assertion
      end

      ##
      # Return a token instance that was built using the access_token data
      # from the response obtained by calling the Lighthouse with a certain
      # set of parameters
      #
      # @return [Lighthouse::Token]
      #
      def fetch
        response = request.post('/oauth2/pgd/v1/token', post_params)

        self.access_token = JSON.parse(response.body).fetch('access_token')
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
        exp = decoded_token.fetch('exp')
        Time.zone.at(exp).utc.to_i - Time.zone.now.utc.to_i - 5
      end

      private

      def post_params
        hash = {
          grant_type: 'client_credentials',
          client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
          client_assertion: claims_token,
          scope: 'launch/patient patient/Patient.read patient/Questionnaire.read patient/QuestionnaireResponse.read',
          launch: user&.icn
        }

        URI.encode_www_form(hash)
      end
    end
  end
end
