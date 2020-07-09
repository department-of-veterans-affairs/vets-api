# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::BenefitClaim do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:participant_id) { '146189' }
  let(:vet_hash) do
    {
      file_number: user.ssn,
      vnp_participant_id: user.participant_id,
      ssn_number: user.ssn,
      benefit_claim_type_end_product: '133',
      first_name: user.first_name,
      last_name: user.last_name,
      vnp_participant_address_id: '113372',
      phone_number: '5555555555',
      address_line_one: '123 Mainstreet',
      address_state_code: 'FL',
      address_country: 'USA',
      address_city: 'Tampa',
      address_zip_code: '22145',
      email_address: 'foo@foo.com'
    }
  end

  describe '#create' do
    it 'returns a BenefitClaim hash' do
      VCR.use_cassette('bgs/benefit_claim/create') do
        benefit_claim = BGS::BenefitClaim.new(
          vnp_benefit_claim: { vnp_benefit_claim_type_code: '130DPNEBNADJ' },
          veteran: vet_hash,
          user: user
        ).create

        expect(benefit_claim).to include(
          {
            benefit_claim_id: '600194635',
            claim_type_code: '130DPNEBNADJ',
            participant_claimant_id: '600061742',
            program_type_code: 'CPL',
            service_type_code: 'CP',
            status_type_code: 'PEND'
          }
        )
      end
    end

    it 'calls BGS::Base#insert_benefit_claim' do
      VCR.use_cassette('bgs/benefit_claim/create') do
        expect_any_instance_of(BGS::Base).to receive(:insert_benefit_claim)
          .with(
            { vnp_benefit_claim_type_code: '130DPNEBNADJ' },
            vet_hash
          )
          .and_call_original

        BGS::BenefitClaim.new(
          vnp_benefit_claim: { vnp_benefit_claim_type_code: '130DPNEBNADJ' },
          veteran: vet_hash,
          user: user
        ).create
      end
    end
  end
end
