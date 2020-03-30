# frozen_string_literal: true

module Form1010cg
  class Submission
    ##
    # A Form1010CG::Submission is the submission of a CaregiversAssistanceClaim (form 10-10CG)
    # Used to store data of the relating record created in the form's ultimate destination (CARMA).
    #
    # More information about CARMA can be found in lib/carma/README.md

    include ActiveModel::Validations
    include Virtus.model(nullify_blank: true)

    attribute :carma_case_id, String # The id of the CARMA Case created from this form submission
    attribute :submitted_at, DateTime # The timestamp of when the submission was accepted in CARMA
    # Associate via ActiveRecord once we create the table and convert this to an active record model
    attribute :claim, SavedClaim::CaregiversAssistanceClaim

    def id
      nil
    end

    def persisted?
      false
    end

    def initialize(args = [])
      args.each { |key, value| send("#{key}=", value) }
    end
  end
end
