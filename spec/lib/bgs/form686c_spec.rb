# frozen_string_literal: true

require 'rails_helper'
require 'bgs/form686c'

RSpec.describe BGS::Form686c do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674) }

  # @TODO: may want to return something else
  it 'returns a hash with proc information' do
    VCR.use_cassette('bgs/form686c/submit') do
      modify_dependents = BGS::Form686c.new(user_object).submit(all_flows_payload)

      expect(modify_dependents).to include(
        :jrn_dt,
        :jrn_lctn_id,
        :jrn_obj_id,
        :jrn_status_type_cd,
        :jrn_user_id,
        :vnp_proc_id
      )
    end
  end

  it 'calls all methods in flow' do
    VCR.use_cassette('bgs/form686c/submit') do
      expect_any_instance_of(BGS::Service).to receive(:create_proc).and_call_original
      expect_any_instance_of(BGS::Service).to receive(:create_proc_form).and_call_original
      expect_any_instance_of(BGS::VnpVeteran).to receive(:create).and_call_original
      expect_any_instance_of(BGS::Dependents).to receive(:create_all).and_call_original
      expect_any_instance_of(BGS::VnpRelationships).to receive(:create_all).and_call_original
      expect_any_instance_of(BGS::StudentSchool).to receive(:create).and_call_original
      expect_any_instance_of(BGS::VnpBenefitClaim).to receive(:create).and_call_original
      expect_any_instance_of(BGS::BenefitClaim).to receive(:create).and_call_original
      expect_any_instance_of(BGS::VnpBenefitClaim).to receive(:update).and_call_original

      BGS::Form686c.new(user_object).submit(all_flows_payload)
    end
  end
end
