# frozen_string_literal: true

require 'pdf_fill/filler'

module Form1010cg
  class CaregiversAssistanceClaim
    extend AttrEncrypted

    attr_encrypted_options.merge!(key: Settings.db_encryption_key, encode: true)

    include ActiveModel::Model
    include ActiveModel::Callbacks
    include ActiveModel::Validations
    include ActiveModel::Serialization
    # include ActiveModel::Validations::Callbacks

    # define the model callback before SetGuid uses it
    define_model_callbacks :initialize
    include SetGuid

    attr_accessor :guid

    attr_encrypted :form

    def initialize(attributes = {})
      run_callbacks :initialize
      super(attributes)
    end

    def form_subjects
      form.nil? ? [] : parsed_form.keys
    end

    def veteran_data
      parsed_form['veteran'] unless form.nil?
    end

    def primary_caregiver_data
      parsed_form['primaryCaregiver'] unless form.nil?
    end

    def secondary_caregiver_one_data
      parsed_form['secondaryCaregiverOne'] unless form.nil?
    end

    def secondary_caregiver_two_data
      parsed_form['secondaryCaregiverTwo'] unless form.nil?
    end

    def to_pdf(filename = nil, **fill_options)
      # We never save the claim, so we don't have an id to provide for the filename.
      # Instead we'll create a filename with this format "10-10cg_{uuid}"
      PdfFill::Filler.fill_form(self, filename || guid, fill_options)
    end

    # alias_method :_to_json, :to_json

    # def to_json
    #   _to_json(except: self.class.encrypted_attributes.keys)
    # end
  end
end

# # frozen_string_literal: true

# require 'pdf_fill/filler'

# class SavedClaim::CaregiversAssistanceClaim < SavedClaim
#   FORM = '10-10CG'

#   def process_attachments!
#     # Inherited from SavedClaim. Disabling since this claim does not require attachements.
#     raise NotImplementedError, 'Not Implemented for Form 10-10CG'
#   end

#   def to_pdf(filename = nil, **fill_options)
#     # We never save the claim, so we don't have an id to provide for the filename.
#     # Instead we'll create a filename with this format "10-10cg_{uuid}"
#     PdfFill::Filler.fill_form(self, filename || guid, fill_options)
#   end

#   # SavedClaims require regional_office to be defined, CaregiversAssistanceClaim has no purpose for it.
#   #
#   # CaregiversAssistanceClaims are not processed regional VA offices.
#   # The claim's form will contain a "Planned Clinic" (a VA facility that the end-user provided in the form).
#   # This facility is where the end-user's point of contact will be for post-submission processing.
#   def regional_office
#     []
#   end

#   def form_subjects
#     form.nil? ? [] : parsed_form.keys
#   end

#   def veteran_data
#     parsed_form['veteran'] unless form.nil?
#   end

#   def primary_caregiver_data
#     parsed_form['primaryCaregiver'] unless form.nil?
#   end

#   def secondary_caregiver_one_data
#     parsed_form['secondaryCaregiverOne'] unless form.nil?
#   end

#   def secondary_caregiver_two_data
#     parsed_form['secondaryCaregiverTwo'] unless form.nil?
#   end

#   alias_method :_to_json, :to_json

#   def to_json
#     _to_json(except: self.class.encrypted_attributes.keys)
#   end
# end
