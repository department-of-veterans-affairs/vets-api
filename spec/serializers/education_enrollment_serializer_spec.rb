# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationEnrollmentSerializer, type: :serializer do
  include SchemaMatchers

  let(:ees) { build :education_enrollment }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(ees, serializer_class: described_class) }

  it 'should include va_file_number' do
    expect(attributes['va_file_number']).to eq(ees.va_file_number)
  end
  it 'should include regional_processing_office' do
    expect(attributes['regional_processing_office']).to eq(ees.regional_processing_office)
  end
  it 'should include eligibility_date' do
    expect(attributes['eligibility_date']).to eq(ees.eligibility_date)
  end
  it 'should include delimiting_date' do
    expect(attributes['delimiting_date']).to eq(ees.delimiting_date)
  end
  it 'should include percentage_benefit' do
    expect(attributes['percentage_benefit']).to eq(ees.percentage_benefit)
  end
  it 'should include original_entitlement' do
    expect(attributes['original_entitlement']).to eq(ees.original_entitlement)
  end
  it 'should include used_entitlement' do
    expect(attributes['used_entitlement']).to eq(ees.used_entitlement)
  end
  it 'should include remaining_entitlement' do
    expect(attributes['remaining_entitlement']).to eq(ees.remaining_entitlement)
  end
  it 'should include enrollment_list' do
    expected = ees.enrollment_list.map(&:with_indifferent_access)
    expect(attributes['enrollment_list']).to eq(expected)
  end
end
