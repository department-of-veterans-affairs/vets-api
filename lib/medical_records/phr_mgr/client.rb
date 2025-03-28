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
    # Initialize the client
    #
    # @param icn [String] MHV patient ICN
    #
    def initialize(icn)
      super()
      raise Common::Exceptions::ParameterMissing, 'ICN' if icn.blank?

      @icn = icn
    end

    ##
    # Run a PHR Manager refresh on the patient.
    #
    # @return [Fixnum] Call status
    #
    def post_phrmgr_refresh
      response = perform(:post, "refresh/#{@icn}", nil, self.class.configuration.phr_headers)
      # response_hash = JSON.parse(response.body)
      response&.status
    end

    ##
    # Run a PHR Manager refresh on the patient.
    #
    # @return [Hash] Patient status
    #
    def get_phrmgr_status
      response = perform(:get, "status/#{@icn}", nil, self.class.configuration.phr_headers)
      response.body
    end

    ##
    ## Get military service record
    # @param edipi
    # @return - military service record in text format
    #
    def get_military_service(edipi)
      headers = self.class.configuration.phr_headers.merge({ 'Accept' => 'text/plain' })
      response = perform(:get, "dod/vaprofile/#{edipi}", nil, headers)
      response.body
    end
  end
end
