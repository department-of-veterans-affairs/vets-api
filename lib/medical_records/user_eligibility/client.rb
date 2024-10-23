# frozen_string_literal: true

require 'common/client/base'
require 'medical_records/user_eligibility/configuration'

module UserEligibility
  ##
  # Core class responsible for User Eligibility API interface operations
  #
  class Client < Common::Client::Base
    configuration UserEligibility::Configuration

    ##
    # Initialize the client
    #
    # @param user_id [String] MHV correlation ID
    # @param icn [String] MHV patient ICN
    #
    def initialize(user_id, icn)
      super()
      raise Common::Exceptions::ParameterMissing, 'User ID' if user_id.blank?
      raise Common::Exceptions::ParameterMissing, 'ICN' if icn.blank?

      @icn = icn
      @user_id = user_id
    end

    ##
    # Run a user eligibility check on the patient
    #
    # @return [Hash] Patient eligibility status
    #
    def get_is_valid_sm_user
      response = perform(:get, "isValidSMUser/#{@user_id}/#{@icn}", nil, self.class.configuration.x_headers)
      response.body
    end
  end
end
