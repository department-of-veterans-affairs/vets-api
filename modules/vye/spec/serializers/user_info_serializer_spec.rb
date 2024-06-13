# frozen_string_literal: true

require 'rails_helper'

describe Vye::UserInfoSerializer, type: :serializer do
  subject { serialize(user_info, serializer_class: described_class) }

  before do
    award = create(:vye_award, user_info:)
    create_list(:vye_verification, 3, user_profile: user_info.user_profile, award:)
    allow(user_info).to receive(:pending_verifications).and_return(user_info.verifications)
  end

  let(:user_info) { create(:vye_user_info) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:relationships) { data['relationships'] }

  it 'includes :rem_ent' do
    expect(attributes['rem_ent']).to eq user_info.rem_ent
  end

  it 'includes :cert_issue_date' do
    expect(attributes['cert_issue_date']).to eq user_info.cert_issue_date.to_s
  end

  it 'includes :del_date' do
    expect(attributes['del_date']).to eq user_info.del_date.to_s
  end

  it 'includes :date_last_certified' do
    expect(attributes['date_last_certified']).to eq user_info.date_last_certified.to_s
  end

  it 'includes :payment_amt' do
    expect(attributes['payment_amt']).to eq user_info.payment_amt.to_s
  end

  it 'includes :indicator' do
    expect(attributes['indicator']).to eq user_info.indicator
  end

  context 'when api_key is set' do
    it 'includes :zip_code' do
      expect(attributes['zip_code']).to eq user_info.zip_code
    end
  end

  context 'when api_key is not set' do
    it 'includes :zip_code' do
      expect(attributes['zip_code']).to eq nil
    end
  end

  it 'includes :latest_address' do
    expect(relationships['latest_address']['data']['id']).to eq user_info.latest_address.id.to_s
  end

  it 'includes :pending_documents' do
    expect(relationships['pending_documents']['data'][0]['id']).to eq user_info.pending_documents.first.id.to_s
  end

  it 'includes :verifications' do
    expect(relationships['verifications']['data'][0]['id']).to eq user_info.verifications.first.id.to_s
  end

  it 'includes :pending_verifications' do
    expect(relationships['pending_verifications']['data'][0]['id']).to eq user_info.pending_verifications.first.id.to_s
  end
end
