# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::PoaFormBuilderJob, type: :job do
  subject { described_class }

  let(:power_of_attorney) { create(:power_of_attorney, :with_full_headers) }
  let(:bad_b64_image) { File.read('modules/claims_api/spec/fixtures/signature_b64_prefix_bad.txt') }

  before do
    Sidekiq::Worker.clear_all
    b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
    power_of_attorney.current_poa = 'ABC'
    power_of_attorney.form_data = {
      recordConcent: true,
      consentAddressChange: true,
      consentLimits: ['DRUG ABUSE', 'SICKLE CELL'],
      signatures: {
        veteran: b64_image,
        representative: b64_image
      },
      veteran: {
        serviceBranch: 'ARMY',
        address: {
          numberAndStreet: '2719 Hyperion Ave',
          city: 'Los Angeles',
          state: 'CA',
          country: 'US',
          zipFirstFive: '92264'
        },
        phone: {
          areaCode: '555',
          phoneNumber: '5551337'
        }
      },
      claimant: {
        firstName: 'Lillian',
        middleInitial: 'A',
        lastName: 'Disney',
        email: 'lillian@disney.com',
        relationship: 'Spouse',
        address: {
          numberAndStreet: '2688 S Camino Real',
          city: 'Palm Springs',
          state: 'CA',
          country: 'US',
          zipFirstFive: '92264'
        },
        phone: {
          areaCode: '555',
          phoneNumber: '5551337'
        }
      },
      serviceOrganization: {
        organizationName: 'I Help Vets LLC',
        address: {
          numberAndStreet: '2719 Hyperion Ave',
          city: 'Los Angeles',
          state: 'CA',
          country: 'US',
          zipFirstFive: '92264'
        }
      }
    }
    power_of_attorney.save
  end

  describe 'generating the filled and signed pdf' do
    context 'when representative is an individual' do
      before do
        Veteran::Service::Representative.new(representative_id: '12345', poa_codes: ['ABC']).save!
      end

      it 'generates the pdf to match example' do
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        expect(ClaimsApi::PoaPdfConstructor::Individual).to receive(:new).and_call_original
        expect_any_instance_of(ClaimsApi::PoaPdfConstructor::Individual).to receive(:construct).and_call_original
        subject.new.perform(power_of_attorney.id)
      end
    end

    context 'when representative is part of an organization' do
      before do
        Veteran::Service::Representative.new(representative_id: '67890', poa_codes: ['ABC']).save!
        Veteran::Service::Organization.create(poa: 'ABC', name: 'Some org')
      end

      it 'generates the pdf to match example' do
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        expect(ClaimsApi::PoaPdfConstructor::Organization).to receive(:new).and_call_original
        expect_any_instance_of(ClaimsApi::PoaPdfConstructor::Organization).to receive(:construct).and_call_original
        subject.new.perform(power_of_attorney.id)
      end
    end

    context 'when signature has prefix' do
      before do
        Veteran::Service::Representative.new(representative_id: '67890', poa_codes: ['ABC']).save!
        Veteran::Service::Organization.create(poa: 'ABC', name: 'Some org')
        power_of_attorney.update(form_data: power_of_attorney.form_data.deep_merge(
          {
            signatures: {
              veteran: bad_b64_image,
              representative: bad_b64_image
            }
          }
        ))
      end

      it 'sets the status and store the error' do
        expect_any_instance_of(ClaimsApi::PoaPdfConstructor::Organization).to receive(:construct)
          .and_raise(ClaimsApi::StampSignatureError)
        subject.new.perform(power_of_attorney.id)
        power_of_attorney.reload
        expect(power_of_attorney.status).to eq(ClaimsApi::PowerOfAttorney::ERRORED)
        expect(power_of_attorney.signature_errors).not_to be_empty
      end
    end
  end
end
