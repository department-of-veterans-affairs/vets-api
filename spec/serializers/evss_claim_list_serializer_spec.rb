# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSClaimListSerializer, type: :serializer do
  let(:evss_claim) { build(:evss_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  subject { serialize(evss_claim, serializer_class: EVSSClaimListSerializer) }

  it 'should include id' do
    expect(data['id']).to eq(evss_claim.evss_id.to_s)
  end

  context 'with different data and list_data' do
    let(:evss_claim) do
      FactoryBot.build(:evss_claim, data: {
                         'waiver5103_submitted': false
                       }, list_data: {
                         'waiver5103_submitted': true
                       })
    end
    it 'should not use object.data' do
      expect(attributes['waiver_submitted']).to eq true
    end
  end
end
