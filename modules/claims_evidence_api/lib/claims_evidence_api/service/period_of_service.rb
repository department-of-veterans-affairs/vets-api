# frozen_string_literal: true

require 'claims_evidence_api/service/base'

module ClaimsEvidenceApi
  module Service
    # PeriodOfService API
    # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Period%20Of%20Service
    class PeriodOfService < Base
      # @see #retrieve
      def self.get(uuid)
        new.retrieve
      end

      # GET retrieve the list of document types
      def retrieve(uuid)
        perform :get, "files/#{uuid}/periodOfService", {}
      end

      private

      # @see ClaimsEvidenceApi::Service::Base#endpoint
      def endpoint
        'period_of_service'
      end

      # end PeriodOfService
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
