# frozen_string_literal: true

require 'attr_encrypted'

module EncryptedVaForm
  extend ActiveSupport::Concern

  # rubocop:disable Metrics/BlockLength
  included do
    validates(:form, presence: true)
    validate(:form_matches_schema)
    validate(:form_must_be_string)

    attr_encrypted(:form, key: Settings.db_encryption_key)

    # create a uuid for this second (used in the confirmation number) and store
    # the form type based on the constant found in the subclass.
    after_initialize do
      self.form_id = self.class::FORM.upcase
    end

    def self.add_form_and_validation(form_id)
      const_set('FORM', form_id)
      validates(:form_id, inclusion: [form_id])
    end

    def parsed_form
      @parsed_form ||= JSON.parse(form)
    end

    def form_is_string
      form.is_a?(String)
    end

    def form_must_be_string
      errors[:form] << 'must be a json string' unless form_is_string
    end

    def form_matches_schema
      return unless form_is_string

      errors[:form].concat(JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[self.class::FORM], parsed_form))
    end

    def update_form(key, value)
      application = parsed_form
      application[key] = value
      self.form = JSON.generate(application)
    end

    def to_pdf(file_name = nil)
      PdfFill::Filler.fill_form(self, file_name)
    end
  end
  # rubocop:enable Metrics/BlockLength
end
