# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/serializers/claims_api/concerns/va_representative'

class DummyRepSerializer
  include JSONAPI::Serializer
  include ClaimsApi::Concerns::VARepresentative

  def self.object_data(object)
    object.data
  end
end

describe ClaimsApi::Concerns::VARepresentative, type: :concern do
  subject { serialize(evss_claim, serializer_class: DummyRepSerializer) }

  let(:evss_claim) { build_stubbed(:evss_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:claim_data) { evss_claim.data }

  it 'includes :va_representative' do
    sanitized_va_rep = ActionView::Base.full_sanitizer.sanitize(evss_claim.data['poa'])&.gsub(/&[^ ;]+;/, '')
    expect(attributes['va_representative']).to eq(sanitized_va_rep)
  end
end
