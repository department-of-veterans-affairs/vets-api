# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::UserInfoSerializer, type: :serializer do
  subject { described_class.new(user_info).to_json }

  before do
    user_profile = user_info.user_profile
    award = create(:vye_award, user_info:)
    create_list(:vye_verification, 3, user_profile:, user_info:, award:)
    allow(user_info).to receive(:pending_verifications).and_return(user_info.verifications)
  end

  let(:user_info) { create(:vye_user_info) }
  let(:data) { JSON.parse(subject)['vye/user_info'] }

  it 'includes :rem_ent' do
    expect(data['rem_ent']).to eq user_info.rem_ent
  end

  it 'includes :cert_issue_date' do
    expect(data['cert_issue_date']).to eq user_info.cert_issue_date.to_s
  end

  it 'includes :del_date' do
    expect(data['del_date']).to eq user_info.del_date.to_s
  end

  it 'includes :date_last_certified' do
    expect(data['date_last_certified']).to eq user_info.date_last_certified.to_s
  end

  it 'includes :payment_amt' do
    expect(data['payment_amt']).to eq user_info.payment_amt.to_s
  end

  it 'includes :indicator' do
    expect(data['indicator']).to eq user_info.indicator
  end

  it 'includes :zip_code' do
    expect(data['zip_code']).to eq user_info.zip_code
  end

  it 'includes :latest_address' do
    expect(data['latest_address']['veteran_name']).to eq user_info.latest_address.veteran_name
  end

  it 'includes :pending_documents' do
    expect(data['pending_documents'][0]['doc_type']).to eq user_info.pending_documents.first.doc_type
  end

  it 'includes :verifications' do
    expect(data['verifications'][0]['award_id']).to eq user_info.verifications.first.award_id
  end

  it 'includes :pending_verifications' do
    expect(data['pending_verifications'][0]['award_id']).to eq user_info.pending_verifications.first.award_id
  end
end
