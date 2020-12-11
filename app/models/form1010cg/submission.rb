# frozen_string_literal: true

module Form1010cg
  # A Form1010CG::Submission is the submission of a CaregiversAssistanceClaim (form 10-10CG)
  # Used to store data of the relating record created in CARMA.
  #
  # More information about CARMA can be found in lib/carma/README.md
  #
  class Submission < ApplicationRecord
    self.table_name = 'form1010cg_submissions'

    belongs_to :claim,
               class_name: 'SavedClaim::CaregiversAssistanceClaim',
               foreign_key: 'claim_guid',
               primary_key: 'guid',
               inverse_of: :submission,
               dependent: :destroy

    # Allows us to call #save with a nested (and unsaved) claim attached, so both are save simultaneously.
    accepts_nested_attributes_for :claim

    attr_accessor :attachments_job_id
  end
end
