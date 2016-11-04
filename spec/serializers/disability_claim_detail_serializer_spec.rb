# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaimDetailSerializer, type: :serializer do
  let(:disability_claim) { build(:disability_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  subject { serialize(disability_claim, serializer_class: DisabilityClaimDetailSerializer) }

  it 'should include id' do
    expect(data['id']).to eq(disability_claim.id.to_s)
  end

  it 'should not include raw HTML' do
    expect(attributes.to_json.to_s.include?('<')).to be(false)
  end

  context 'with HTML in the description' do
    let(:disability_claim) do
      FactoryGirl.build(:disability_claim, data: {
                          'claimTrackedItems': {
                            'stillNeedFromYouList': [
                              {
                                description: 'this has <h1>HTML</h1>'
                              }
                            ]
                          }
                        })
    end
    it 'strips the HTML tags' do
      expect(attributes['events_timeline'][0]['description']).to eq('this has HTML')
    end
  end

  context 'with different data and list_data' do
    let(:disability_claim) do
      FactoryGirl.build(:disability_claim, data: {
                          'waiver5103Submitted': true
                        }, list_data: {
                          'waiver5103Submitted': false
                        })
    end
    it 'should not use list_data' do
      expect(attributes['waiver_submitted']).to eq true
    end
  end
end
