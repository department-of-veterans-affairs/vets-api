# frozen_string_literal: true

class PPMS::ProviderFacility < Common::Base
  attribute :id, String
  attribute :providers, Array
  attribute :facilities, Array

  def initialize(attr = {})
    super(attr)
    @id = SecureRandom.uuid
  end

  def provider_ids
    providers.collect(&:id)
  end

  def facility_ids
    facilities.collect(&:id)
  end
end
