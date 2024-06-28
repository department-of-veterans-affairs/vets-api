# frozen_string_literal: true

require 'rails_helper'

describe ContactSerializer, type: :serializer do
  subject { serialize(contact, serializer_class: described_class) }

  let(:contact) { build_stubbed(:associated_person) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id as contact_type' do
    expect(data['id']).to eq contact.contact_type
  end

  it 'includes :contact_type' do
    expect(attributes['contact_type']).to eq contact.contact_type
  end

  it 'includes :given_name' do
    expect(attributes['given_name']).to eq contact.given_name
  end

  it 'includes :middle_name' do
    expect(attributes['middle_name']).to eq contact.middle_name
  end

  it 'includes :family_name' do
    expect(attributes['family_name']).to eq contact.family_name
  end

  it 'includes :relationship' do
    expect(attributes['relationship']).to eq contact.relationship
  end

  it 'includes :address_line1' do
    expect(attributes['address_line1']).to eq contact.address_line1
  end

  it 'includes :address_line2' do
    expect(attributes['address_line2']).to eq contact.address_line2
  end

  it 'includes :address_line3' do
    expect(attributes['address_line3']).to eq contact.address_line3
  end

  it 'includes :city' do
    expect(attributes['city']).to eq contact.city
  end

  it 'includes :state' do
    expect(attributes['state']).to eq contact.state
  end

  it 'includes :zip_code' do
    expect(attributes['zip_code']).to eq contact.zip_code
  end

  it 'includes :primary_phone' do
    expect(attributes['primary_phone']).to eq contact.primary_phone
  end
end
