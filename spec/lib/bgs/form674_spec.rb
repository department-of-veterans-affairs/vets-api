# frozen_string_literal: true

require 'rails_helper'
require 'bgs/form674'

RSpec.describe BGS::Form674 do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674) }

  # @TODO: may want to return something else
  it 'returns a hash with proc information' do
    VCR.use_cassette('bgs/form674/submit') do
      VCR.use_cassette('bid/awards/get_awards_pension') do
        modify_dependents = BGS::Form674.new(user_object).submit(all_flows_payload)

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
  end

  it 'calls all methods in flow' do
    VCR.use_cassette('bgs/form674/submit') do
      VCR.use_cassette('bid/awards/get_awards_pension') do
        expect_any_instance_of(BGS::Service).to receive(:create_proc).and_call_original
        expect_any_instance_of(BGS::Service).to receive(:create_proc_form).and_call_original
        expect_any_instance_of(BGS::VnpVeteran).to receive(:create).and_call_original
        expect_any_instance_of(BGS::BenefitClaim).to receive(:create).and_call_original
        expect_any_instance_of(BGS::StudentSchool).to receive(:create).and_call_original
        expect_any_instance_of(BGS::VnpBenefitClaim).to receive(:create).and_call_original
        expect_any_instance_of(BGS::VnpBenefitClaim).to receive(:update).and_call_original
        expect_any_instance_of(BGS::VnpRelationships).to receive(:create_all).and_call_original
        expect_any_instance_of(BID::Awards::Service).to receive(:get_awards_pension).and_call_original

        BGS::Form674.new(user_object).submit(all_flows_payload)
      end
    end
  end
end
