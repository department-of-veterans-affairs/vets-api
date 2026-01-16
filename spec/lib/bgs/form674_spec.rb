# frozen_string_literal: true

require 'rails_helper'
require 'bgs/form674'

RSpec.describe BGS::Form674 do
  let(:user_object) { create(:evss_user, :loa3) }
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:all_flows_v2_payload) { build(:form686c_674_v2) }
  let(:user_struct) { build(:user_struct) }
  let(:saved_claim) { create(:dependency_claim) }
  let(:saved_claim_674_only) { create(:dependency_claim_674_only) }

  before do
    # performance tweak
    allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:pdf_overflow_tracking)
  end

  context 'The system is able to submit 674s automatically' do
    # @TODO: may want to return something else
    it 'returns a hash with proc information' do
      VCR.use_cassette('bgs/form674/submit') do
        VCR.use_cassette('bid/awards/get_awards_pension') do
          VCR.use_cassette('bgs/service/create_note') do
            modify_dependents = BGS::Form674.new(user_struct, saved_claim).submit(all_flows_v2_payload)

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
    end

    it 'calls all methods in flow and submits an automated claim' do
      VCR.use_cassette('bgs/form674/submit') do
        expect_any_instance_of(BGS::Service).to receive(:create_proc).and_call_original
        expect_any_instance_of(BGS::Service).to receive(:create_proc_form).and_call_original
        expect_any_instance_of(BGS::VnpVeteran).to receive(:create).and_call_original
        expect_any_instance_of(BGS::BenefitClaim).to receive(:create).and_call_original
        expect_any_instance_of(BGS::StudentSchool).to receive(:create).and_call_original
        expect_any_instance_of(BGS::VnpBenefitClaim).to receive(:create).and_call_original
        expect_any_instance_of(BGS::VnpBenefitClaim).to receive(:update).and_call_original
        expect_any_instance_of(BGS::VnpRelationships).to receive(:create_all).and_call_original

        BGS::Form674.new(user_struct, saved_claim_674_only).submit(all_flows_v2_payload)
      end
    end

    it 'submits a manual claim with pension' do
      VCR.use_cassette('bgs/form674/submit') do
        VCR.use_cassette('bid/awards/get_awards_pension') do
          VCR.use_cassette('bgs/service/create_note') do
            allow(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(true)
            expect_any_instance_of(BID::Awards::Service).to receive(:get_awards_pension).and_call_original

            BGS::Form674.new(user_struct, saved_claim).submit(all_flows_v2_payload)
          end
        end
      end
    end
  end
end
