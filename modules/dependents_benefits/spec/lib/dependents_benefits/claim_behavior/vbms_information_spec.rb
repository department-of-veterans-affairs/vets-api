# frozen_string_literal: true

require 'rails_helper'

require 'bid/awards/service'
require 'dependents_benefits/claim_behavior/vbms_information'

RSpec.describe DependentsBenefits::ClaimBehavior::VBMSInformation do
  let(:claim) { create(:dependents_claim) }
  let(:parsed_form) { claim.parsed_form }
  let(:user) { double('User', participant_id: 'participant_id') }
  let(:bid_service) { double('BID::Awards::Service', get_awards_pension: awards_response) }
  let(:awards_response) { double('response', body: { 'awards_pension' => { 'is_in_receipt_of_pension' => true } }) }

  before do
    allow(Flipper).to receive(:enabled?).with(:dependents_removal_check).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:dependents_pension_check).and_return(true)

    allow(BID::Awards::Service).to receive(:new).and_return(bid_service)

    allow(claim).to receive(:parsed_form).and_return(parsed_form)
  end

  describe '#get_claim_information' do
    it 'returns expected values' do
      info = claim.get_claim_information(user)
      expected = {
        proc_state: 'MANUAL_VAGOV',
        note_text: /^Claim set to manual by VA.gov/,
        claim_label: '130SSRDPMCE',
        participant_id: 'participant_id'
      }
      expect(info).to match(a_hash_including(**expected))
    end

    context 'with different selectable options' do
      it 'covers none selected' do
        parsed_form['view:selectable686_options'] = {}

        info = claim.get_claim_information(user)
        expected = { proc_state: 'Started', claim_label: '130DPNEBNADJ' }
        expect(info).to match(a_hash_including(**expected))
      end

      it 'covers report_marriage_of_child_under18' do
        parsed_form['view:selectable686_options'] = { 'report_marriage_of_child_under18' => true }

        info = claim.get_claim_information(user)
        expected = { proc_state: 'MANUAL_VAGOV', claim_label: '130SSRDPMCE' }
        expect(info).to match(a_hash_including(**expected))
      end

      it 'covers report_child18_or_older_is_not_attending_school' do
        parsed_form['view:selectable686_options'] = { 'report_child18_or_older_is_not_attending_school' => true }

        info = claim.get_claim_information(user)
        expected = { proc_state: 'MANUAL_VAGOV', claim_label: '130SSRDPMCE' }
        expect(info).to match(a_hash_including(**expected))
      end

      it 'covers add_spouse' do
        parsed_form['view:selectable686_options'] = { 'add_spouse' => true }
        parsed_form['dependents_application']['current_marriage_information']['type_of_marriage'] = 'OTHER'

        info = claim.get_claim_information(user)
        expected = { proc_state: 'MANUAL_VAGOV', claim_label: '130DAEBNPMCR' }
        expect(info).to match(a_hash_including(**expected))
      end

      it 'covers report_death' do
        parsed_form['view:selectable686_options'] = { 'report_death' => true }

        info = claim.get_claim_information(user)
        expected = { proc_state: 'MANUAL_VAGOV', claim_label: '130SSRDPMCE' }
        expect(info).to match(a_hash_including(**expected))
      end

      it 'covers report674' do
        parsed_form['view:selectable686_options'] = { 'report674' => true }

        info = claim.get_claim_information(user)
        expected = { proc_state: 'MANUAL_VAGOV', claim_label: '130DAEBNPMCR' }
        expect(info).to match(a_hash_including(**expected))
      end

      it 'covers report_divorce' do
        parsed_form['view:selectable686_options'] = { 'report_divorce' => true }

        info = claim.get_claim_information(user)
        expected = { proc_state: 'Started', claim_label: '130SSRDPMC' }
        expect(info).to match(a_hash_including(**expected))
      end
    end

    context 'without receiving pension' do
      before do
        no_pension = double('response', body: { 'awards_pension' => { 'is_in_receipt_of_pension' => false } })
        allow(bid_service).to receive(:get_awards_pension).and_return(no_pension)
      end

      it 'covers add_spouse' do
        parsed_form['view:selectable686_options'] = { 'add_spouse' => true }
        parsed_form['dependents_application']['current_marriage_information']['type_of_marriage'] = 'OTHER'

        info = claim.get_claim_information(user)
        expected = { proc_state: 'MANUAL_VAGOV', claim_label: '130DPEBNAJRE' }
        expect(info).to match(a_hash_including(**expected))
      end

      it 'covers report_death' do
        parsed_form['view:selectable686_options'] = { 'report_death' => true }

        info = claim.get_claim_information(user)
        expected = { proc_state: 'MANUAL_VAGOV', claim_label: '130SSRDE' }
        expect(info).to match(a_hash_including(**expected))
      end

      it 'covers report_divorce' do
        parsed_form['view:selectable686_options'] = { 'report_divorce' => true }

        info = claim.get_claim_information(user)
        expected = { proc_state: 'Started', claim_label: '130SSRD' }
        expect(info).to match(a_hash_including(**expected))
      end
    end
  end
end
