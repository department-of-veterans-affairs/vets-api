# frozen_string_literal: true

module CARMA
  module Models
    class Submission
      # request
      attr_accessor :data
      attr_accessor :metadata

      # response
      attr_accessor :carma_case_id
      attr_accessor :submitted_at

      # Returns a new CARMA::Models::Submission built from a CaregiversAssistanceClaim.
      #
      #
      # @param claim [CaregiversAssistanceClaim] A validated CaregiversAssistanceClaim
      # @param metadata [Hash] Additional data that can be submitted along with the claim's form data
      # @return [CARMA::Models::Submission] A CARMA Submission model object
      #
      def self.from_claim(claim, metadata = {})
        new(
          data: claim.parsed_form, # No data transformation yet, just a one-to-one mapping of properties
          metadata: metadata.merge(claim_id: claim.id)
        )
      end

      def initialize(args = {})
        @client = CARMA::Client::Client.new
        @carma_case_id = args[:carma_case_id]
        @submitted_at = args[:submitted_at]
        @data = args[:data]
        @metadata = CARMA::Models::Submission::Metadata.new(args[:metadata] || {})
      end

      def submit!
        raise 'This submission has already been submitted to CARMA' if submitted?

        response = @client.create_submission_stub(to_request_payload)

        @carma_case_id = response['data']['carmacase']['id']
        @submitted_at = response['data']['carmacase']['createdAt']

        self
      end

      def submitted?
        @submitted_at.present? || @carma_case_id.present?
      end

      def to_request_payload
        { data: @data, metadata: metadata.to_request_payload }
      end

      class Metadata
        class Veteran
          include ActiveModel::Validations
          include Virtus.model(nullify_blank: true)

          # The ICN of the veteran specified on the form submission data.
          # This will be nil if we could not find an ICN with the supplied information on the form submission.
          attribute :icn, String

          # A flag signifying that we have confirmed the person in the "veteran" field of the form submission
          # data is a veteran.
          # The value will be
          # true - We confirmed their veteran status
          # false - We confirmed that they are not a veteran
          # nil - We could not confirm nor deny that they are a veteran
          attribute :is_veteran, Boolean

          validates(:icn, presence: true)
        end

        class Caregiver
          include ActiveModel::Validations
          include Virtus.model(nullify_blank: true)

          attribute :icn, String
        end

        include ActiveModel::Validations
        include Virtus.model(nullify_blank: true)

        attribute :claim_id, Integer
        attribute :veteran, Veteran
        attribute :primary_caregiver, Caregiver
        attribute :secondary_caregiver_one, Caregiver
        attribute :secondary_caregiver_two, Caregiver

        validates(:claim_id, :veteran, :primary_caregiver, presence: true)

        def to_request_payload
          { claim_id: claim_id }
        end
      end
    end
  end
end
