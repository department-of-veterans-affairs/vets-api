# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/serializers/claims_api/concerns/contention_list'

class DummyContentionSerializer
  include JSONAPI::Serializer
  include ClaimsApi::Concerns::ContentionList

  def self.object_data(object)
    object.data
  end
end

describe ClaimsApi::Concerns::ContentionList, type: :concern do
  subject { serialize(claim, serializer_class: DummyContentionSerializer) }

  let(:claim) { build_stubbed(:evss_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:claim_data) { claim.data }

  it 'includes :contention_list' do
    expect(attributes['contention_list']).to eq(claim_data['contention_list'])
  end
end
