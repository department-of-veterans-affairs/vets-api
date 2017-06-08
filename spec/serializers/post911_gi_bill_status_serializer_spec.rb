# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Post911GIBillStatusSerializer, type: :serializer do
  include SchemaMatchers

  let(:post911gibs) { build :post911_gi_bill_status }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(post911gibs, serializer_class: described_class) }

  it 'should include va_file_number' do
    expect(attributes['va_file_number']).to eq(post911gibs.va_file_number)
  end
  it 'should include regional_processing_office' do
    expect(attributes['regional_processing_office']).to eq(post911gibs.regional_processing_office)
  end
  it 'should include eligibility_date' do
    expect(attributes['eligibility_date']).to eq(post911gibs.eligibility_date)
  end
  it 'should include delimiting_date' do
    expect(attributes['delimiting_date']).to eq(post911gibs.delimiting_date)
  end
  it 'should include percentage_benefit' do
    expect(attributes['percentage_benefit']).to eq(post911gibs.percentage_benefit)
  end
  it 'should include original_entitlement' do
    expect(attributes['original_entitlement']).to eq(post911gibs.original_entitlement)
  end
  it 'should include used_entitlement' do
    expect(attributes['used_entitlement']).to eq(post911gibs.used_entitlement)
  end
  it 'should include remaining_entitlement' do
    expect(attributes['remaining_entitlement']).to eq(post911gibs.remaining_entitlement)
  end
  it 'should include enrollment_list' do
    expected = post911gibs.enrollment_list.map(&:with_indifferent_access)
    expect(attributes['enrollment_list']).to eq(expected)
  end
end
