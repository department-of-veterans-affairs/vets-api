# frozen_string_literal: true

require 'claims_evidence_api/service/base'

module ClaimsEvidenceApi
  module Service
    # Association API
    # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Association
    class Association < Base
      # @see #retrieve
      def self.get(uuid)
        new.retrieve(uuid)
      end

      # @see #associate
      def self.put(uuid, claim_ids = [])
        new.associate(uuid, claim_ids)
      end

      # GET retrieve the list of associated claims
      # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Association/getAssociation
      #
      # @param uuid [String] The UUID of the file data
      def retrieve(uuid)
        perform :get, "files/#{uuid}/associations/claims", {}
      end

      # PUT update associated claims for a specific UUID
      # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Association/associate
      #
      # This endpoint when given a array of claim_ids compares the list to those already associated and
      # removes the missing claim associations and adds the new ones.
      #
      # @param uuid [String] The UUID of the file data
      # @param claim_ids [Array<String>] the full list of associated claim_ids
      def associate(uuid, claim_ids = [])
        associated = { associatedClaimIds: claim_ids.map(&:to_s) }
        perform :put, "files/#{uuid}/associations/claims", associated
      end

      private

      # @see ClaimsEvidenceApi::Service::Base#endpoint
      def endpoint
        'association'
      end

      # end Association
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
