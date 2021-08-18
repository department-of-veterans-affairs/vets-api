# frozen_string_literal: true

module ChipApi
  ##
  # An object responsible for handling JWT claims used for CHIP authentication
  #
  class ClaimsToken
    ##
    # Builds a ChipApi::ClaimsToken instance
    #
    # @return [ChipApi::ClaimsToken] an instance of this class
    #
    def self.build
      new
    end

    ##
    # Return the temporary base64 encoded token that CHIP setup for
    # the vets-api for the MVP check-in project. This will be converted
    # to a dynamic claims token in future iterations
    #
    # @return [String]
    #
    def static
      @static ||= Base64.encode64("#{chip_api.tmp_api_username}:#{chip_api.tmp_api_user}")
    end

    ##
    # Return the temporary vets-api id set by CHIP in their Sandbox environment
    #
    # @return [String]
    #
    def api_id
      chip_api.tmp_api_id
    end

    private

    def chip_api
      Settings.check_in.chip_api
    end
  end
end
