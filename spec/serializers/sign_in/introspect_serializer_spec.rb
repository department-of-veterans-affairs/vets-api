# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::IntrospectSerializer do
  subject { serialize(user, serializer_class: described_class) }

  let(:user) do
    create(:user, :loa3,
           middle_name: middle_name, logingov_uuid: logingov_uuid, idme_uuid: idme_uuid,
           mhv_ids: mhv_ids, active_mhv_ids: mhv_ids, participant_id: participant_id)
  end
  let(:middle_name) { 'some-middle-name' }
  let(:logingov_uuid) { 'some-logingov-uuid' }
  let(:idme_uuid) { 'some-idme-uuid' }
  let(:mhv_ids) { %w[123 456] }
  let(:participant_id) { 'some-participant-id' }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  before do
    user.send(:mpi_profile).id_theft_flag = true
  end

  it 'returns serialized #uuid data' do
    expect(attributes['uuid']).to be_present
  end

  it 'returns serialized #first_name data' do
    expect(attributes['first_name']).to be_present
  end

  it 'returns serialized #middle_name data' do
    expect(attributes['middle_name']).to be_present
  end

  it 'returns serialized #last_name data' do
    expect(attributes['last_name']).to be_present
  end

  it 'returns serialized #birth_date data' do
    expect(attributes['birth_date']).to be_present
  end

  it 'returns serialized #email data' do
    expect(attributes['email']).to be_present
  end

  it 'returns serialized #gender data' do
    expect(attributes['gender']).to be_present
  end

  it 'returns serialized #idme_uuid data' do
    expect(attributes['idme_uuid']).to be_present
  end

  it 'returns serialized #logingov_uuid data' do
    expect(attributes['logingov_uuid']).to be_present
  end

  it 'returns serialized #ssn data' do
    expect(attributes['ssn']).to be_present
  end

  it 'returns serialized #icn data' do
    expect(attributes['icn']).to be_present
  end

  it 'returns serialized #edipi data' do
    expect(attributes['edipi']).to be_present
  end

  it 'returns serialized #active_mhv_ids data' do
    expect(attributes['active_mhv_ids']).to be_present
  end

  it 'returns serialized #sec_id data' do
    expect(attributes['sec_id']).to be_present
  end

  it 'returns serialized #vet360_id data' do
    expect(attributes['vet360_id']).to be_present
  end

  it 'returns serialized #participant_id data' do
    expect(attributes['participant_id']).to be_present
  end

  it 'returns serialized #cerner_id data' do
    expect(attributes['cerner_id']).to be_present
  end

  it 'returns serialized #cerner_facility_ids data' do
    expect(attributes['cerner_facility_ids']).to be_present
  end

  it 'returns serialized #vha_facility_ids data' do
    expect(attributes['vha_facility_ids']).to be_present
  end

  it 'returns serialized #id_theft_flag data' do
    expect(attributes['id_theft_flag']).to be_present
  end

  it 'returns serialized #authn_context data' do
    expect(attributes['authn_context']).to be_present
  end

  describe '#verified' do
    let(:expected_verified) { 'some-expected-verified' }

    before do
      allow(user).to receive(:loa3?).and_return(expected_verified)
    end

    it 'returns serialized #verified data' do
      expect(attributes['verified']).to be_present
    end

    it 'returns verified value that maps to existing loa3? function' do
      expect(attributes['verified']).to eq(expected_verified)
    end
  end
end
