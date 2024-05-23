# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::IntentToFileSerializer do

  # based on ClaimsApi::V1::Forms::IntentToFileController#active bgs_active
  let(:bgs_response) do
    {
      create_dt: "2020-06-05T11:24:28-05:00",
      exprtn_dt: "2021-06-05T11:24:28-05:00",
      intent_to_file_id: "183042",
      itf_status_type_cd: "Active",
      itf_type_cd: "C",
      jrn_dt: "2020-06-05T11:24:28-05:00",
      jrn_extnl_key_txt: "dslogon.1013590059",
      jrn_extnl_user_id: "dslogon.1013590059",
      jrn_lctn_id: "281",
      jrn_obj_id: "eBenefits",
      jrn_status_type_cd: "I",
      jrn_user_id: "VAEBENEFITS",
      ptcpnt_clmant_id: "13367440",
      ptcpnt_vet_id: "13367440",
      rcvd_dt: "2020-06-05T11:24:28-05:00",
      status_dt: "2020-06-05T11:24:28-05:00",
      submtr_applcn_type_cd: "VETS.GOV"
    }
  end

  let(:rendered_hash) { ActiveModelSerializers::SerializableResource.new(bgs_response, {serializer: described_class} ).as_json }
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :creation_date' do
    expect(rendered_attributes[:creation_date]).to eq bgs_response[:create_dt]
  end

  it 'includes :expiration_date' do
    expect(rendered_attributes[:expiration_date]).to eq bgs_response[:exprtn_dt]
  end

  it 'includes :type' do
    expect(rendered_attributes[:type]).to eq ClaimsApi::IntentToFile::ITF_TYPES_TO_BGS_TYPES.key(bgs_response[:itf_type_cd])
  end

  it 'includes :status' do
    expect(rendered_attributes[:status]).to eq bgs_response[:itf_status_type_cd]&.downcase
  end

end
