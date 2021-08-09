# frozen_string_literal: true

module ChipApi
  ##
  # An object responsible for fetching and building access_tokens
  # from the ChipApi for the ChipApi::Session object.
  #
  # @!attribute request
  #   @return [ChipApi::Request]
  # @!attribute claims_token
  #   @return [ChipApi::ClaimsToken]
  # @!attribute access_token
  #   @return [String]
  class Token
    attr_reader :request, :claims_token
    attr_accessor :access_token

    ##
    # Builds a ChipApi::Token instance
    #
    # @return [ChipApi::Token] an instance of this class
    #
    def self.build
      new
    end

    def initialize
      @request = Request.build
      @claims_token = ClaimsToken.build
    end

    ##
    # Return a token instance that was built using the claims_token
    #
    # @return [ChipApi::Token]
    #
    def fetch
      response = request.post(path: "/#{base_path}/token", claims_token: claims_token.static)

      self.access_token = Oj.load(response.body)['token']
      self
    end

    ##
    # Return the duration for which the saved redis session is valid
    #
    # @return [Integer]
    #
    def ttl_duration
      900
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
    # Helper method for returning the Chip URL base path
    # from our environment configuration file
    #
    # @return [String]
    #
    def base_path # rubocop:disable Rails/Delegate
      chip_api.base_path
    end

    ##
    # Return the CHIP API settings from config
    #
    # @return [String]
    #
    def chip_api
      Settings.check_in.chip_api
    end
  end
end
