# frozen_string_literal: true

require 'rails_helper'

describe PPIUSerializer, type: :serializer do
  subject { serialize(payment_information_response, serializer_class: described_class) }

  let(:payment_information_response) { build(:ppiu_payment_information_response) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :type' do
    expect(data['type']).to eq 'evss_ppiu_payment_information_responses'
  end

  it 'includes :responses' do
    expect(attributes['responses'].size).to eq payment_information_response.responses.size
  end

  it 'includes :enrollments with attributes' do
    expected_attributes = payment_information_response.responses.first.attributes.keys.map(&:to_s)
    expect(attributes['responses'].first.keys).to eq expected_attributes
  end

  it 'masks the account number' do
    account_number = payment_information_response.responses.first.payment_account.account_number
    masked_account_number = StringHelpers.mask_sensitive(account_number)
    expect(attributes['responses'].first['payment_account']['account_number']).to eq(masked_account_number)
  end

  it 'masks the routing number' do
    routing_number = payment_information_response.responses.first.payment_account.financial_institution_routing_number
    masked_routing_number = StringHelpers.mask_sensitive(routing_number)
    given_routing_number = attributes['responses'].first['payment_account']['financial_institution_routing_number']
    expect(given_routing_number).to eq(masked_routing_number)
  end
end
