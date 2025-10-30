# frozen_string_literal: true

class SavedClaim::Form21p530a < SavedClaim
  FORM = '21P-530a'

  validates :form, presence: true

  # When an OpenAPI schema is added, this can be overridden similar to Form214192
  # Waiting on another PR to be merged first
  #
  # def form_schema
  #   schema = JSON.parse(Openapi::Requests::Form21p530a::FORM_SCHEMA.to_json)
  #   schema['components'] = JSON.parse(Openapi::Components::ALL.to_json)
  #   schema
  # end

  # This will be removed once OpenAPI schema is added.
  # see app/models/saved_claim/form214192.rb for an example of what this will look like
  def form_matches_schema
    true
  end

  def process_attachments!
    Lighthouse::SubmitBenefitsIntakeClaim.perform_async(id)
  end

  def send_confirmation_email
    # Email functionality not included for MVP
  end

  # SavedClaims require regional_office to be defined
  def regional_office
    [].freeze
  end

  # Burial-related claims route to NCA business line
  def business_line
    'NCA'
  end

  # VBMS document type for burial applications
  def document_type
    133
  end

  def attachment_keys
    # No attachments supported for MVP
    [].freeze
  end
end
