# frozen_string_literal: true

require 'rails_helper'
require 'bgs/form686c'
require 'bid/awards/service'

RSpec.describe BGS::Form686c do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674) }

  # @TODO: may want to return something else
  it 'returns a hash with proc information' do
    VCR.use_cassette('bgs/form686c/submit') do
      VCR.use_cassette('bid/awards/get_awards_pension') do
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
  end

  it 'calls all methods in flow' do
    VCR.use_cassette('bgs/form686c/submit') do
      VCR.use_cassette('bid/awards/get_awards_pension') do
        expect_any_instance_of(BGS::Service).to receive(:create_proc).and_call_original
        expect_any_instance_of(BGS::Service).to receive(:create_proc_form).and_call_original
        expect_any_instance_of(BGS::VnpVeteran).to receive(:create).and_call_original
        expect_any_instance_of(BGS::Dependents).to receive(:create_all).and_call_original
        expect_any_instance_of(BGS::VnpRelationships).to receive(:create_all).and_call_original
        expect_any_instance_of(BGS::VnpBenefitClaim).to receive(:create).and_call_original
        expect_any_instance_of(BGS::BenefitClaim).to receive(:create).and_call_original
        expect_any_instance_of(BGS::VnpBenefitClaim).to receive(:update).and_call_original
        expect_any_instance_of(BGS::Service).to receive(:update_proc).with('3831475', { proc_state: 'MANUAL_VAGOV' })
        expect_any_instance_of(BID::Awards::Service).to receive(:get_awards_pension).and_call_original

        BGS::Form686c.new(user_object).submit(all_flows_payload)
      end
    end
  end

  it 'submits a non-manual claim' do
    VCR.use_cassette('bgs/form686c/submit') do
      claim = BGS::Form686c.new(user_object)

      expect(claim).to receive(:get_state_type).and_return 'Started'
      expect_any_instance_of(BGS::Service).to receive(:update_proc).with('3831475', { proc_state: 'Ready' })

      claim.submit(all_flows_payload)
    end
  end
end
