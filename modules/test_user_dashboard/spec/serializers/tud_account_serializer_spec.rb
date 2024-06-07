# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::TudAccountSerializer do
  let(:tud_account) { build_stubbed(:tud_account) }
  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(tud_account, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to eq tud_account.id.to_s
  end

  it 'includes :account_uuid' do
    expect(rendered_attributes[:account_uuid]).to eq tud_account.account_uuid
  end

  it 'includes :first_name' do
    expect(rendered_attributes[:first_name]).to eq tud_account.first_name
  end

  it 'includes :middle_name' do
    expect(rendered_attributes[:middle_name]).to eq tud_account.middle_name
  end

  it 'includes :last_name' do
    expect(rendered_attributes[:last_name]).to eq tud_account.last_name
  end

  it 'includes :gender' do
    expect(rendered_attributes[:gender]).to eq tud_account.gender
  end

  it 'includes :birth_date' do
    expect(rendered_attributes[:birth_date]).to eq tud_account.birth_date
  end

  it 'includes :ssn' do
    expect(rendered_attributes[:ssn]).to eq tud_account.ssn
  end

  it 'includes :phone' do
    expect(rendered_attributes[:phone]).to eq tud_account.phone
  end

  it 'includes :email' do
    expect(rendered_attributes[:email]).to eq tud_account.email
  end

  it 'includes :password' do
    expect(rendered_attributes[:password]).to eq tud_account.password
  end

  it 'includes :available' do
    expect(rendered_attributes[:available]).to eq tud_account.available?
  end

  it 'includes :checkout_time' do
    expect(rendered_attributes[:checkout_time]).to eq tud_account.checkout_time
  end

  it 'includes :id_types' do
    expect(rendered_attributes[:id_types]).to eq tud_account.id_types
  end

  it 'includes :loa' do
    expect(rendered_attributes[:loa]).to eq tud_account.loa
  end

  it 'includes :services' do
    expect(rendered_attributes[:services]).to eq tud_account.services
  end

  it 'includes :notes' do
    expect(rendered_attributes[:notes]).to eq tud_account.notes
  end

  it 'includes :mfa_code' do
    expect(rendered_attributes[:mfa_code]).to eq tud_account.mfa_code
  end
end
