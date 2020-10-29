# frozen_string_literal: true

require 'carma/client/client'
require_relative 'base'
require_relative 'metadata'

module CARMA
  module Models
    class Submission < Base
      attr_reader :metadata, :request_body
      attr_accessor :data, :carma_case_id, :submitted_at

      request_payload_key :data, :metadata
      after_to_request_payload :clear_veteran_icn

      def clear_veteran_icn(data)
        # The values metadata.veteran.icn and metadata.veteran.isVeteran are used together
        # to create the proper Person type in CARMA.
        #
        # CARMA requires metadata.veteran.icn to be null if metadata.veteran.isVeteran is false
        # If metadata.veteran.isVeteran is true, an icn must be present.
        #
        # This is only the case for metadata.veteran and not other metadata namespaces.
        data['metadata']['veteran']['icn'] = nil unless data['metadata']['veteran']['isVeteran'] == true
        data
      end

      # Returns a new CARMA::Models::Submission built from a CaregiversAssistanceClaim.
      #
      #
      # @param claim [CaregiversAssistanceClaim] A validated CaregiversAssistanceClaim
      # @param metadata [Hash] Additional data that can be submitted along with the claim's form data
      # @return [CARMA::Models::Submission] A CARMA Submission model object
      #
      def self.from_claim(claim, metadata = {})
        new(
          data: claim.parsed_form,
          metadata: metadata.merge(claim_id: claim.id, claim_guid: claim.guid)
        )
      end

      def initialize(args = {})
        self.carma_case_id = args[:carma_case_id]
        self.submitted_at = args[:submitted_at]
        self.data = args[:data]
        self.metadata = args[:metadata] || {}
      end

      def submit!(client)
        raise 'This submission has already been submitted to CARMA' if submitted?

        @request_body = to_request_payload

        response = client.create_submission(request_body)

        @carma_case_id = response['data']['carmacase']['id']
        @submitted_at = response['data']['carmacase']['createdAt']

        self
      end

      def submitted?
        @submitted_at.present? || @carma_case_id.present?
      end

      def metadata=(metadata_hash)
        @metadata = Metadata.new(metadata_hash)
      end
    end
  end
end
