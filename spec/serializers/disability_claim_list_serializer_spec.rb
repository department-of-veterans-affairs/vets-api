# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaimListSerializer, type: :serializer do
  let(:disability_claim) { build(:disability_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  subject { serialize(disability_claim, serializer_class: DisabilityClaimListSerializer) }

  it 'should include id' do
    expect(data['id']).to eq(disability_claim.id.to_s)
  end

  context 'with different data and list_data' do
    let(:disability_claim) do
      FactoryGirl.build(:disability_claim, data: {
                          'waiver5103Submitted': false
                        }, list_data: {
                          'waiver5103Submitted': true
                        })
    end
    it 'should not use object.data' do
      expect(attributes['waiver_submitted']).to eq true
    end
  end
end
