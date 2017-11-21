# frozen_string_literal: true
require 'attr_encrypted'

# Base class to hold common functionality for Claim submissions.
# Subclasses need to several constants and methods defined:
# * `FORM` should align with the identifier of the form as found in
#    the vets-json-schema struct so that validations can be run on submit
# * `CONFIRMATION` should be a small ident used as part of the confirmation
#    number to quickly determine the form/product type
# *  Optionally `PERSISTENT_CLASS`, which is a subclass of `PersistentAttachment`
#    that can be used when the subclass implements to_pdf as a way to convert
#    the raw submission into a filled PDF using the PdfFill lib.
# *  `regional_office()`, which returns an array or string of the location of
#    the claim processing facility
# *  `attachment_keys()` returns a list of symbols corresponding to the keys
#    in the JSON submission of file upload references. These are iterated over
#    in the `process_attachments!` method to associate the previously unmoored
#    files to the submitted claim, and to begin processing them.

class SavedClaim < ActiveRecord::Base
  include SetGuid

  validates(:form, presence: true)
  validate(:form_matches_schema)
  validate(:form_must_be_string)
  attr_encrypted(:form, key: Settings.db_encryption_key)

  has_many :persistent_attachments

  # create a uuid for this second (used in the confirmation number) and store
  # the form type based on the constant found in the subclass.
  after_initialize do
    self.form_id = self.class::FORM.upcase
  end

  def self.add_form_and_validation(form_id)
    const_set('FORM', form_id)
    validates(:form_id, inclusion: [form_id])
  end

  # Run after a claim is saved, this processes any files and workflows that are present
  # and sends them to our internal partners for processing.
  def process_attachments!
    GenerateClaimPDFJob.perform_async(id) if respond_to?(:to_pdf)
    refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
    files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
    files.update_all(saved_claim_id: id)
    persistent_attachments.map(&:process)
    true
  end

  # Return a unique confirmation number that somewhat masks the sequentialness.
  def confirmation_number
    "V-#{self.class::CONFIRMATION}-#{guid[0..6]}#{id}".upcase
  end

  # Convert the json into an OStruct
  def open_struct_form
    @application ||= JSON.parse(form, object_class: OpenStruct)
  end

  def parsed_form
    @parsed_form ||= JSON.parse(form)
  end

  def submitted_at
    created_at
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

  def to_pdf
    File.open(PdfFill::Filler.fill_form(self))
  end

  private

  def attachment_keys
    []
  end
end
