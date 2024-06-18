# frozen_string_literal: true

require 'rails_helper'

describe PhoneNumberSerializer, type: :serializer do
  subject { serialize(phone, serializer_class: described_class) }

  let(:phone) { build(:phone_number) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :number' do
    expect(attributes['number']).to eq phone.number
  end

  it 'includes :extension' do
    expect(attributes['extension']).to eq phone.extension
  end

  it 'includes :country_code' do
    expect(attributes['country_code']).to eq phone.country_code
  end

  it 'includes :effective_date' do
    expect_time_eq(attributes['effective_date'], phone.effective_date)
  end
end
