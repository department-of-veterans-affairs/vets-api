# frozen_string_literal: true

require 'common/client/base'
require 'medical_records/phr_mgr/configuration'

module PHRMgr
  ##
  # Core class responsible for PHR Manager API interface operations
  #
  class Client < Common::Client::Base
    configuration PHRMgr::Configuration

    ##
    # Run a PHR Manager refresh on the patient with the given ICN number.
    #
    # @param icn [String] MHV patient ICN
    # @return [Fixnum] Call status
    #
    def post_phrmgr_refresh(icn)
      raise Common::Exceptions::ParameterMissing, 'ICN' if icn.blank?

      response = perform(:post, "refresh/#{icn}", nil, self.class.configuration.x_auth_key_headers)
      # response_hash = JSON.parse(response.body)
      response&.status
    end

    ##
    # Run a PHR Manager refresh on the patient with the given ICN number.
    #
    # @param icn [String] MHV patient ICN
    # @return [Hash] Patient status
    #
    def get_phrmgr_status(icn)
      raise Common::Exceptions::ParameterMissing, 'ICN' if icn.blank?

      response = perform(:get, "status/#{icn}", nil, self.class.configuration.x_auth_key_headers)
      response.body
    end
  end
end
