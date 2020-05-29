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
  class Submission < ApplicationRecord
    self.table_name = 'form1010cg_submissions'

    belongs_to :saved_claim, class_name: 'SavedClaim::CaregiversAssistanceClaim'

    validates :carma_case_id, presence: true
    validates :submitted_at, presence: true
  end
end
