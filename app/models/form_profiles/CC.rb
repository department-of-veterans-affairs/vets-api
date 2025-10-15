# frozen_string_literal: true

class FormProfiles::CC < FormProfile
  attribute :claim_id, String

  def prefill
    form_data = create_claim
    { form_data:, metadata: }
  rescue => e
    Rails.logger.error("Complex Claims Form prefill failed: #{e.message}")
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/name-and-date-of-birth'
    }
  end

  private

  def create_claim
    { claim_id: SecureRandom.uuid }
  end
end
