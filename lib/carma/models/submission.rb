# frozen_string_literal: true

module CARMA
  module Models
    class Submission
      # request
      attr_accessor :data
      attr_accessor :metadata

      # response
      attr_accessor :case_id
      attr_accessor :submitted_at

      # Returns a new CARMA::Models::Submission built from a CaregiversAssistanceClaim.
      #
      #
      # @param claim [CaregiversAssistanceClaim] A validated CaregiversAssistanceClaim
      # @param metadata [Hash] Additional data that can be submitted along with the claim's form data
      # @return [CARMA::Models::Submission] A persisted instance of Account
      #
      def self.from_claim(claim, metadata = {})
        new(
          data: claim.parsed_form, # No data transformation yet, just a one-to-one mapping of properties
          metadata: metadata.merge(claim_id: claim.id)
        )
      end

      def initialize(args = {})
        @client = CARMA::Client::Client.new
        @case_id = args[:case_id]
        @submitted_at = args[:submitted_at]
        @data = args[:data]
        @metadata = CARMA::Models::Submission::Metadata.new(args[:metadata] || {})
      end

      def submit!
        raise 'This submission has already been submitted to CARMA' if submitted?

        response = @client.create_submission(to_request_payload)

        @case_id = response[:data][:case][:id]
        @submitted_at = response[:data][:case][:created_at]

        self
      end

      def submitted?
        @submitted_at.present? || @case_id.present?
      end

      def to_request_payload
        { data: @data, metadata: metadata.to_request_payload }
      end

      class Metadata
        attr_reader :claim_id

        def initialize(args = {})
          @claim_id = args[:claim_id]
        end

        def to_request_payload
          { claim_id: claim_id }
        end
      end
    end
  end
end
