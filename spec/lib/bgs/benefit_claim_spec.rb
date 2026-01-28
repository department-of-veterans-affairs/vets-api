# frozen_string_literal: true

require 'rails_helper'
require 'bgs/benefit_claim'

RSpec.describe BGS::BenefitClaim do
  let(:user_object) { create(:evss_user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:participant_id) { '146189' }
  let(:vet_hash) do
    {
      file_number: user_object.ssn,
      vnp_participant_id: user_object.participant_id,
      ssn_number: user_object.ssn,
      benefit_claim_type_end_product: '133',
      first_name: user_object.first_name,
      last_name: user_object.last_name,
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
          args: {
            vnp_benefit_claim: { vnp_benefit_claim_type_code: '130DPNEBNADJ' },
            veteran: vet_hash,
            user: user_object,
            proc_id:,
            end_product_name: '130 - Automated Dependency 686c',
            end_product_code: '130DPNEBNADJ'
          }
        ).create

        expect(benefit_claim).to include(
          {
            benefit_claim_id: '600196508',
            claim_type_code: '130DPNEBNADJ',
            participant_claimant_id: '600061742',
            program_type_code: 'CPL',
            service_type_code: 'CP',
            status_type_code: 'PEND'
          }
        )
      end
    end

    it 'calls BGS::Service#insert_benefit_claim' do
      VCR.use_cassette('bgs/benefit_claim/create') do
        expect_any_instance_of(BGS::BenefitClaimWebService).to receive(:insert_benefit_claim)
          .with(
            a_hash_including(
              {
                ptcpnt_id_claimant: '600061742',
                ssn: '796043735',
                file_number: '796043735',
                date_of_claim: Time.current.strftime('%m/%d/%Y'),
                end_product: '133',
                end_product_code: '130DPNEBNADJ',
                end_product_name: '130 - Automated Dependency 686c',
                first_name: 'WESLEY',
                last_name: 'FORD',
                payee: '00'
              }
            )
          )
          .and_call_original

        BGS::BenefitClaim.new(
          args: {
            vnp_benefit_claim: { vnp_benefit_claim_type_code: '130DPNEBNADJ' },
            veteran: vet_hash,
            user: user_object,
            proc_id:,
            end_product_name: '130 - Automated Dependency 686c',
            end_product_code: '130DPNEBNADJ'
          }
        ).create
      end
    end

    it 'removes apostrophes and other characters forbidden by BGS, from the names in the payload to BGS' do
      user_object = create(:evss_user, :loa3, first_name: "D'Añgelo", last_name: "O'Briën")
      expect_any_instance_of(BGS::Service)
        .to receive(:insert_benefit_claim)
        .with(a_hash_including({ first_name: 'DAngelo', last_name: 'OBrien' }))
        .and_return({})

      BGS::BenefitClaim.new(
        args: {
          vnp_benefit_claim: { vnp_benefit_claim_type_code: '130DPNEBNADJ' },
          veteran: vet_hash,
          user: user_object,
          proc_id:,
          end_product_name: '130 - Automated Dependency 686c',
          end_product_code: '130DPNEBNADJ'
        }
      ).create
    end

    context 'error' do
      it 'handles error' do
        vet_hash[:file_number] = nil

        VCR.use_cassette('bgs/benefit_claim/create/error') do
          expect_any_instance_of(BGS::BenefitClaim).to receive(:handle_error).with(
            anything, 'create'
          )

          BGS::BenefitClaim.new(
            args: {
              vnp_benefit_claim: { vnp_benefit_claim_type_code: '130DPNEBNADJ' },
              veteran: vet_hash,
              user: user_object,
              proc_id:
            }
          ).create
        end
      end

      it 'handles updates proc to manual' do
        vet_hash[:file_number] = nil

        VCR.use_cassette('bgs/benefit_claim/create/error') do
          expect do
            BGS::BenefitClaim.new(
              args: {
                vnp_benefit_claim: { vnp_benefit_claim_type_code: '130DPNEBNADJ' },
                veteran: vet_hash,
                user: user_object,
                proc_id:
              }
            ).create
          end.to raise_error(BGS::ServiceException)
        end
      end
    end
  end
end
