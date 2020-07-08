# frozen_string_literal: true

module Form1010cg
  # A Form1010CG::Submission is the submission of a CaregiversAssistanceClaim (form 10-10CG)
  # Used to store data of the relating record created in the form's ultimate destination (CARMA).
  #
  # More information about CARMA can be found in lib/carma/README.md
  #
  # @!attribute claim
  #   @return [SavedClaim::CaregiversAssistanceClaim] the associated SavedClaim
  # @!attribute carma_case_id
  #   @return [String] The id of the CARMA Case created from this form submission
  # @!attribute submitted_at
  #   @return [DateTime] The timestamp of when the submission was accepted in CARMA
  #
  class Submission
    attr_accessor :carma_case_id # The id of the CARMA Case created from this form submission
    attr_accessor :submitted_at # The timestamp of when the submission was accepted in CARMA
    attr_accessor :attachments

    def initialize(args = {})
      @carma_case_id = args[:carma_case_id]
      @submitted_at = args[:submitted_at]
      @attachments = args[:attachments] || []
    end
  end
end
