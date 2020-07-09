# frozen_string_literal: true

require 'rails_helper'
RSpec.describe BGS::Form686c do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:fixtures_path) { "#{Rails.root}/spec/fixtures/686c/dependents" }
  let(:all_flows_payload) do
    payload = File.read("#{fixtures_path}/all_flows_payload.json")
    JSON.parse(payload)
  end

  # TODO: may want to return something else
  it 'returns a hash with proc information' do
    VCR.use_cassette('bgs/form686c/submit') do
      modify_dependents = BGS::Form686c.new(user).submit(all_flows_payload)

      expect(modify_dependents).to include(:jrn_dt, :jrn_lctn_id, :jrn_obj_id, :jrn_status_type_cd, :jrn_user_id, :vnp_proc_id)
    end
  end

  it 'creates a VnpVeteran' do
    VCR.use_cassette('bgs/form686c/submit') do
      expect_any_instance_of(BGS::Service).to receive(:create_proc).and_call_original
      expect_any_instance_of(BGS::Service).to receive(:create_proc_form).and_call_original
      expect_any_instance_of(BGS::VnpVeteran).to receive(:create).and_call_original
      expect_any_instance_of(BGS::Dependents).to receive(:create).and_call_original
      expect_any_instance_of(BGS::VnpRelationships).to receive(:create).and_call_original
      expect_any_instance_of(BGS::VnpBenefitClaim).to receive(:create).and_call_original
      expect_any_instance_of(BGS::BenefitClaim).to receive(:create).and_call_original
      expect_any_instance_of(BGS::VnpBenefitClaim).to receive(:update).and_call_original

      BGS::Form686c.new(user).submit(all_flows_payload)
    end
  end
end
