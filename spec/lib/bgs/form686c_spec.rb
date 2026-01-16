# frozen_string_literal: true

require 'rails_helper'
require 'bgs/form686c'

RSpec.describe BGS::Form686c do
  let(:user_object) { create(:evss_user, :loa3) }
  let(:user_struct) { build(:user_struct) }
  let(:saved_claim) { create(:dependency_claim_no_vet_information) }

  before do
    allow(Flipper).to receive(:enabled?).and_call_original
  end

  describe '#submit' do
    subject { form686c.submit(payload) }

    context 'The flipper is turned on' do
      let(:form686c) { BGS::Form686c.new(user_struct, saved_claim) }

      context 'form_686c_674_kitchen_sink' do
        let(:payload) { build(:form686c_674_v2) }

        # @TODO: may want to return something else
        it 'returns a hash with proc information' do
          VCR.use_cassette('bgs/form686c/submit') do
            VCR.use_cassette('bid/awards/get_awards_pension') do
              VCR.use_cassette('bgs/service/create_note') do
                expect(subject).to include(
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
              expect_any_instance_of(BGS::Service).to receive(:update_proc).with('3831475',
                                                                                 { proc_state: 'MANUAL_VAGOV' })
              expect_any_instance_of(BID::Awards::Service).to receive(:get_awards_pension).and_call_original
              expect_any_instance_of(BGS::Service).to receive(:create_note).with(
                '600210032',
                'Claim set to manual by VA.gov: This application needs manual review because a 686 was submitted ' \
                'for removal of a step-child that has left household.'
              )

              subject
            end
          end
        end

        it 'submits a non-manual claim' do
          VCR.use_cassette('bgs/form686c/submit') do
            expect(form686c).to receive(:get_state_type).and_return 'Started'
            expect(Flipper).to receive(:enabled?).with(:dependents_removal_check).and_return(false)
            expect(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(false)
            expect_any_instance_of(BGS::Service).to receive(:update_proc).with('3831475', { proc_state: 'Ready' })
            subject
          end
        end

        it 'submits a manual claim with pension disabled' do
          VCR.use_cassette('bgs/form686c/submit') do
            VCR.use_cassette('bgs/service/create_note') do
              expect(form686c).to receive(:set_claim_type).with('MANUAL_VAGOV',
                                                                payload['view:selectable686_options']).and_call_original
              expect(Flipper).to receive(:enabled?).with(:dependents_removal_check).and_return(false)
              expect(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(false)
              subject
            end
          end
        end

        it 'submits a manual claim with pension enabled' do
          VCR.use_cassette('bgs/form686c/submit') do
            VCR.use_cassette('bid/awards/get_awards_pension') do
              VCR.use_cassette('bgs/service/create_note') do
                expect(Flipper).to receive(:enabled?).with(:dependents_removal_check).and_return(true)
                expect(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(true)
                expect_any_instance_of(BID::Awards::Service).to receive(:get_awards_pension).and_call_original

                BGS::Form686c.new(user_struct, saved_claim).submit(payload)
              end
            end
          end
        end
      end

      context 'form_686c_add_child_report674' do
        let(:payload) { build(:form686c_674_v2) }

        it 'submits a manual claim with the correct BGS note' do
          VCR.use_cassette('bgs/form686c/submit') do
            VCR.use_cassette('bid/awards/get_awards_pension') do
              VCR.use_cassette('bgs/service/create_note') do
                expect_any_instance_of(BGS::Service).to receive(:update_proc).with('3831475',
                                                                                   { proc_state: 'MANUAL_VAGOV' })
                expect_any_instance_of(BGS::Service).to receive(:create_note).with(
                  '600210032',
                  'Claim set to manual by VA.gov: This application needs manual review because a 686 was submitted ' \
                  'for removal of a step-child that has left household.'
                )

                subject
              end
            end
          end
        end
      end
    end

    context 'The flipper is turned off' do
      let(:form686c) { BGS::Form686c.new(user_object, saved_claim) }

      context 'form_686c_674_kitchen_sink' do
        let(:payload) { build(:form686c_674_v2) }

        # @TODO: may want to return something else
        it 'returns a hash with proc information' do
          VCR.use_cassette('bgs/form686c/submit') do
            VCR.use_cassette('bid/awards/get_awards_pension') do
              VCR.use_cassette('bgs/service/create_note') do
                expect(subject).to include(
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
              expect_any_instance_of(BGS::Service).to receive(:update_proc).with('3831475',
                                                                                 { proc_state: 'MANUAL_VAGOV' })
              expect_any_instance_of(BID::Awards::Service).to receive(:get_awards_pension).and_call_original
              expect_any_instance_of(BGS::Service).to receive(:create_note).with(
                '600210032',
                'Claim set to manual by VA.gov: This application needs manual review because a 686 was submitted ' \
                'for removal of a step-child that has left household.'
              )

              subject
            end
          end
        end

        it 'submits a non-manual claim' do
          VCR.use_cassette('bgs/form686c/submit') do
            expect(form686c).to receive(:get_state_type).and_return 'Started'
            expect(Flipper).to receive(:enabled?).with(:dependents_removal_check).and_return(false)
            expect(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(false)
            expect_any_instance_of(BGS::Service).to receive(:update_proc).with('3831475', { proc_state: 'Ready' })
            subject
          end
        end

        it 'submits a manual claim with pension disabled' do
          VCR.use_cassette('bgs/form686c/submit') do
            VCR.use_cassette('bgs/service/create_note') do
              expect(form686c).to receive(:set_claim_type).with('MANUAL_VAGOV',
                                                                payload['view:selectable686_options']).and_call_original
              expect(Flipper).to receive(:enabled?).with(:dependents_removal_check).and_return(false)
              expect(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(false)
              subject
            end
          end
        end

        it 'submits a manual claim with pension enabled' do
          VCR.use_cassette('bgs/form686c/submit') do
            VCR.use_cassette('bid/awards/get_awards_pension') do
              VCR.use_cassette('bgs/service/create_note') do
                expect(Flipper).to receive(:enabled?).with(:dependents_removal_check).and_return(true)
                expect(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(true)
                expect_any_instance_of(BID::Awards::Service).to receive(:get_awards_pension).and_call_original

                BGS::Form686c.new(user_object, saved_claim).submit(payload)
              end
            end
          end
        end
      end

      context 'form_686c_add_child_report674' do
        let(:payload) { build(:form686c_674_v2) }

        it 'submits a manual claim with the correct BGS note' do
          VCR.use_cassette('bgs/form686c/submit') do
            VCR.use_cassette('bid/awards/get_awards_pension') do
              VCR.use_cassette('bgs/service/create_note') do
                expect_any_instance_of(BGS::Service).to receive(:update_proc).with('3831475',
                                                                                   { proc_state: 'MANUAL_VAGOV' })
                expect_any_instance_of(BGS::Service).to receive(:create_note).with(
                  '600210032',
                  'Claim set to manual by VA.gov: This application needs manual review because a 686 was submitted ' \
                  'for removal of a step-child that has left household.'
                )

                subject
              end
            end
          end
        end
      end
    end
  end
end
