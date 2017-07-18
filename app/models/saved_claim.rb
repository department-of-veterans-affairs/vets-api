# frozen_string_literal: true
require 'attr_encrypted'
class SavedClaim < ActiveRecord::Base
  validates(:form, presence: true)
  validate(:form_matches_schema)
  validate(:form_must_be_string)
  attr_encrypted(:form, key: Settings.db_encryption_key)

  has_many :persistent_attachments

  after_initialize do
    self.guid ||= SecureRandom.uuid
    # TODO move this to only burials and pensions
    self.form_id = self.class::FORM.upcase
  end

  def process_attachments!
    GenerateClaimPDFJob.perform_async(id) if respond_to?(:to_pdf)
    refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
    files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
    files.update_all(saved_claim_id: id)
    files.reload.each.map(&:process)
    true
  end

  def confirmation_number
    "V-#{self.class::CONFIRMATION}-#{guid[0..6]}#{id}".upcase
  end

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
