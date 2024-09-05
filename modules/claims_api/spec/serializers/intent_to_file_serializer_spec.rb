# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::IntentToFileSerializer, type: :serializer do
  include SerializerSpecHelper

  # based on ClaimsApi::V1::Forms::IntentToFileController#active bgs_active
  subject { serialize(bgs_response, serializer_class: described_class) }

  let(:bgs_response) do
    {
      create_dt: '2020-06-05T11:24:28-05:00',
      exprtn_dt: '2021-06-05T11:24:28-05:00',
      intent_to_file_id: '183042',
      itf_status_type_cd: 'Active',
      itf_type_cd: 'C',
      jrn_dt: '2020-06-05T11:24:28-05:00',
      jrn_extnl_key_txt: 'dslogon.1013590059',
      jrn_extnl_user_id: 'dslogon.1013590059',
      jrn_lctn_id: '281',
      jrn_obj_id: 'eBenefits',
      jrn_status_type_cd: 'I',
      jrn_user_id: 'VAEBENEFITS',
      ptcpnt_clmant_id: '13367440',
      ptcpnt_vet_id: '13367440',
      rcvd_dt: '2020-06-05T11:24:28-05:00',
      status_dt: '2020-06-05T11:24:28-05:00',
      submtr_applcn_type_cd: 'VETS.GOV'
    }
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq bgs_response[:intent_to_file_id]
  end

  it 'includes :creation_date' do
    expect(attributes['creation_date']).to eq bgs_response[:create_dt]
  end

  it 'includes :expiration_date' do
    expect(attributes['expiration_date']).to eq bgs_response[:exprtn_dt]
  end

  it 'includes :type' do
    itf_to_bgs_types = ClaimsApi::IntentToFile::ITF_TYPES_TO_BGS_TYPES
    expect(attributes['type']).to eq itf_to_bgs_types.key(bgs_response[:itf_type_cd])
  end

  it 'includes :status' do
    expect(attributes['status']).to eq bgs_response[:itf_status_type_cd]&.downcase
  end
end
