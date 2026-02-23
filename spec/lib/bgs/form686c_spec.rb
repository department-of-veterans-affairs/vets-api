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

  describe '#set_claim_type' do
    let(:form686c) { BGS::Form686c.new(user_struct, saved_claim) }
    let(:bid_service) { instance_double(BID::Awards::Service) }
    let(:selectable_options) do
      {
        'report_child18_or_older_is_not_attending_school' => false,
        'report_stepchild_not_in_household' => false,
        'report_marriage_of_child_under18' => false,
        'report_death' => false,
        'report_divorce' => false,
        'add_spouse' => false,
        'report674' => false
      }
    end

    before do
      allow(form686c).to receive(:bid_service).and_return(bid_service)
      allow(bid_service).to receive(:get_awards_pension).and_return(
        double(body: { 'awards_pension' => { 'is_in_receipt_of_pension' => false } })
      )
    end

    context 'when dependents_removal_check flipper is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:dependents_removal_check).and_return(true)
      end

      context 'when dependents_pension_check flipper is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(true)
        end

        context 'when proc_state is MANUAL_VAGOV' do
          context 'when removing dependent and receiving pension' do
            let(:options_with_removal) { selectable_options.merge('report_death' => true) }

            before do
              allow(bid_service).to receive(:get_awards_pension).and_return(
                double(body: { 'awards_pension' => { 'is_in_receipt_of_pension' => true } })
              )
            end

            it 'sets PMC exception end product for manual removal with pension' do
              form686c.send(:set_claim_type, 'MANUAL_VAGOV', options_with_removal)

              expect(form686c.instance_variable_get(:@end_product_name)).to eq(
                'PMC - Self Service - Removal of Dependent Exceptn'
              )
              expect(form686c.instance_variable_get(:@end_product_code)).to eq('130SSRDPMCE')
            end
          end

          context 'when removing dependent and not receiving pension' do
            let(:options_with_removal) { selectable_options.merge('report_divorce' => true) }

            it 'sets exception end product for manual removal without pension' do
              form686c.send(:set_claim_type, 'MANUAL_VAGOV', options_with_removal)

              expect(form686c.instance_variable_get(:@end_product_name)).to eq(
                'Self Service - Removal of Dependent Exception'
              )
              expect(form686c.instance_variable_get(:@end_product_code)).to eq('130SSRDE')
            end
          end

          context 'when not removing dependent but receiving pension' do
            before do
              allow(bid_service).to receive(:get_awards_pension).and_return(
                double(body: { 'awards_pension' => { 'is_in_receipt_of_pension' => true } })
              )
            end

            it 'sets PMC reject end product for manual with pension' do
              form686c.send(:set_claim_type, 'MANUAL_VAGOV', selectable_options)

              expect(form686c.instance_variable_get(:@end_product_name)).to eq(
                'PMC eBenefits Dependency Adjustment Reject'
              )
              expect(form686c.instance_variable_get(:@end_product_code)).to eq('130DAEBNPMCR')
            end
          end

          context 'when not removing dependent and not receiving pension' do
            it 'sets reject end product for manual without pension' do
              form686c.send(:set_claim_type, 'MANUAL_VAGOV', selectable_options)

              expect(form686c.instance_variable_get(:@end_product_name)).to eq('eBenefits Dependency Adjustment Reject')
              expect(form686c.instance_variable_get(:@end_product_code)).to eq('130DPEBNAJRE')
            end
          end
        end

        context 'when proc_state is Started' do
          context 'when removing dependent and receiving pension' do
            let(:options_with_removal) do
              selectable_options.merge('report_child18_or_older_is_not_attending_school' => true)
            end

            before do
              allow(bid_service).to receive(:get_awards_pension).and_return(
                double(body: { 'awards_pension' => { 'is_in_receipt_of_pension' => true } })
              )
            end

            it 'sets PMC removal end product' do
              form686c.send(:set_claim_type, 'Started', options_with_removal)

              expect(form686c.instance_variable_get(:@end_product_name)).to eq(
                'PMC - Self Service - Removal of Dependent'
              )
              expect(form686c.instance_variable_get(:@end_product_code)).to eq('130SSRDPMC')
            end
          end

          context 'when removing dependent and not receiving pension' do
            let(:options_with_removal) { selectable_options.merge('report_stepchild_not_in_household' => true) }

            it 'sets removal end product' do
              form686c.send(:set_claim_type, 'Started', options_with_removal)

              expect(form686c.instance_variable_get(:@end_product_name)).to eq('Self Service - Removal of Dependent')
              expect(form686c.instance_variable_get(:@end_product_code)).to eq('130SSRD')
            end
          end

          context 'when not removing dependent' do
            it 'keeps default end product values' do
              original_name = form686c.instance_variable_get(:@end_product_name)
              original_code = form686c.instance_variable_get(:@end_product_code)

              form686c.send(:set_claim_type, 'Started', selectable_options)

              expect(form686c.instance_variable_get(:@end_product_name)).to eq(original_name)
              expect(form686c.instance_variable_get(:@end_product_code)).to eq(original_code)
            end

            it 'does not call pension service when not removing dependent' do
              expect(bid_service).not_to receive(:get_awards_pension)
              form686c.send(:set_claim_type, 'Started', selectable_options)
            end
          end
        end
      end

      context 'when dependents_pension_check flipper is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(false)
        end

        context 'when proc_state is MANUAL_VAGOV and removing dependent' do
          let(:options_with_removal) { selectable_options.merge('report_marriage_of_child_under18' => true) }

          it 'sets exception end product without checking pension' do
            expect(bid_service).not_to receive(:get_awards_pension)

            form686c.send(:set_claim_type, 'MANUAL_VAGOV', options_with_removal)

            expect(form686c.instance_variable_get(:@end_product_name)).to eq(
              'Self Service - Removal of Dependent Exception'
            )
            expect(form686c.instance_variable_get(:@end_product_code)).to eq('130SSRDE')
          end
        end

        context 'when proc_state is MANUAL_VAGOV and not removing dependent' do
          it 'sets reject end product without checking pension' do
            expect(bid_service).not_to receive(:get_awards_pension)

            form686c.send(:set_claim_type, 'MANUAL_VAGOV', selectable_options)

            expect(form686c.instance_variable_get(:@end_product_name)).to eq('eBenefits Dependency Adjustment Reject')
            expect(form686c.instance_variable_get(:@end_product_code)).to eq('130DPEBNAJRE')
          end
        end

        context 'when proc_state is Started and removing dependent' do
          let(:options_with_removal) { selectable_options.merge('report_death' => true) }

          it 'sets removal end product without checking pension' do
            expect(bid_service).not_to receive(:get_awards_pension)

            form686c.send(:set_claim_type, 'Started', options_with_removal)

            expect(form686c.instance_variable_get(:@end_product_name)).to eq('Self Service - Removal of Dependent')
            expect(form686c.instance_variable_get(:@end_product_code)).to eq('130SSRD')
          end
        end
      end
    end

    context 'when dependents_removal_check flipper is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:dependents_removal_check).and_return(false)
      end

      context 'when dependents_pension_check flipper is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(true)
        end

        context 'when proc_state is MANUAL_VAGOV' do
          context 'when receiving pension' do
            before do
              allow(bid_service).to receive(:get_awards_pension).and_return(
                double(body: { 'awards_pension' => { 'is_in_receipt_of_pension' => true } })
              )
            end

            it 'sets PMC reject end product' do
              form686c.send(:set_claim_type, 'MANUAL_VAGOV', selectable_options)

              expect(form686c.instance_variable_get(:@end_product_name)).to eq(
                'PMC eBenefits Dependency Adjustment Reject'
              )
              expect(form686c.instance_variable_get(:@end_product_code)).to eq('130DAEBNPMCR')
            end
          end

          context 'when not receiving pension' do
            it 'sets reject end product' do
              form686c.send(:set_claim_type, 'MANUAL_VAGOV', selectable_options)

              expect(form686c.instance_variable_get(:@end_product_name)).to eq('eBenefits Dependency Adjustment Reject')
              expect(form686c.instance_variable_get(:@end_product_code)).to eq('130DPEBNAJRE')
            end
          end
        end

        context 'when proc_state is Started' do
          it 'keeps default end product values' do
            original_name = form686c.instance_variable_get(:@end_product_name)
            original_code = form686c.instance_variable_get(:@end_product_code)

            form686c.send(:set_claim_type, 'Started', selectable_options)

            expect(form686c.instance_variable_get(:@end_product_name)).to eq(original_name)
            expect(form686c.instance_variable_get(:@end_product_code)).to eq(original_code)
          end

          it 'does not call pension service' do
            expect(bid_service).not_to receive(:get_awards_pension)
            form686c.send(:set_claim_type, 'Started', selectable_options)
          end
        end
      end

      context 'when dependents_pension_check flipper is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(false)
        end

        context 'when proc_state is MANUAL_VAGOV' do
          it 'sets reject end product without pension check' do
            expect(bid_service).not_to receive(:get_awards_pension)

            form686c.send(:set_claim_type, 'MANUAL_VAGOV', selectable_options)

            expect(form686c.instance_variable_get(:@end_product_name)).to eq('eBenefits Dependency Adjustment Reject')
            expect(form686c.instance_variable_get(:@end_product_code)).to eq('130DPEBNAJRE')
          end
        end

        context 'when proc_state is Started' do
          it 'keeps default end product values' do
            original_name = form686c.instance_variable_get(:@end_product_name)
            original_code = form686c.instance_variable_get(:@end_product_code)

            form686c.send(:set_claim_type, 'Started', selectable_options)

            expect(form686c.instance_variable_get(:@end_product_name)).to eq(original_name)
            expect(form686c.instance_variable_get(:@end_product_code)).to eq(original_code)
          end

          it 'does not call pension service' do
            expect(bid_service).not_to receive(:get_awards_pension)
            form686c.send(:set_claim_type, 'Started', selectable_options)
          end
        end
      end
    end

    context 'edge cases' do
      before do
        allow(Flipper).to receive(:enabled?).with(:dependents_removal_check).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(true)
      end

      it 'detects removal when multiple removal options are true' do
        options_multiple_removal = selectable_options.merge(
          'report_death' => true,
          'report_divorce' => true
        )

        form686c.send(:set_claim_type, 'Started', options_multiple_removal)

        expect(form686c.instance_variable_get(:@end_product_name)).to eq('Self Service - Removal of Dependent')
        expect(form686c.instance_variable_get(:@end_product_code)).to eq('130SSRD')
      end

      it 'handles all removal child options correctly' do
        BGS::Form686c::REMOVE_CHILD_OPTIONS.each do |option|
          options_with_single_removal = selectable_options.merge(option => true)

          form686c.send(:set_claim_type, 'Started', options_with_single_removal)

          expect(form686c.instance_variable_get(:@end_product_name)).to eq('Self Service - Removal of Dependent')
          expect(form686c.instance_variable_get(:@end_product_code)).to eq('130SSRD')
        end
      end
    end
  end
end
