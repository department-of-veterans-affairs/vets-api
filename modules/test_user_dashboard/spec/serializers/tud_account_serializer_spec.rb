# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::TudAccountSerializer, type: :serializer do
  subject { serialize(tud_account, serializer_class: described_class) }

  let(:tud_account) { build_stubbed(:tud_account) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq tud_account.id.to_s
  end

  it 'includes :account_uuid' do
    expect(attributes['account_uuid']).to eq tud_account.account_uuid
  end

  it 'includes :first_name' do
    expect(attributes['first_name']).to eq tud_account.first_name
  end

  it 'includes :middle_name' do
    expect(attributes['middle_name']).to eq tud_account.middle_name
  end

  it 'includes :last_name' do
    expect(attributes['last_name']).to eq tud_account.last_name
  end

  it 'includes :gender' do
    expect(attributes['gender']).to eq tud_account.gender
  end

  it 'includes :birth_date' do
    expect(attributes['birth_date']).to eq tud_account.birth_date
  end

  it 'includes :ssn' do
    expect(attributes['ssn']).to eq tud_account.ssn
  end

  it 'includes :phone' do
    expect(attributes['phone']).to eq tud_account.phone
  end

  it 'includes :email' do
    expect(attributes['email']).to eq tud_account.email
  end

  it 'includes :password' do
    expect(attributes['password']).to eq tud_account.password
  end

  it 'includes :available' do
    expect(attributes['available']).to eq tud_account.available?
  end

  it 'includes :checkout_time' do
    expect(attributes['checkout_time']).to eq tud_account.checkout_time
  end

  it 'includes :id_types' do
    expect(attributes['id_types']).to eq tud_account.id_types
  end

  it 'includes :loa' do
    expect(attributes['loa']).to eq tud_account.loa
  end

  it 'includes :services' do
    expect(attributes['services']).to eq tud_account.services
  end

  it 'includes :notes' do
    expect(attributes['notes']).to eq tud_account.notes
  end

  it 'includes :mfa_code' do
    expect(attributes['mfa_code']).to eq tud_account.mfa_code
  end
end
