# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Create do
  describe '#call' do
    subject do
      described_class.new(claimant:, form_data:, poa_code:,
                          registration_number:)
    end

    let(:claimant) { create(:user_account_with_verification) }
    let(:form_data) do
      {
        'authorizations' => {
          'recordDisclosure' => true,
          'recordDisclosureLimitations' => ['HIV'],
          'addressChange' => true
        },
        'dependent' => {
          'name' => {
            'first' => 'Bob',
            'middle' => 'E',
            'last' => 'Claimant'
          },
          'address' => {
            'addressLine1' => '123 Fake Claimant St',
            'addressLine2' => 'Apt 2',
            'city' => 'Eugene',
            'stateCode' => 'OR',
            'country' => 'US',
            'zipCode' => '54321',
            'zipCodeSuffix' => '9876'
          },
          'dateOfBirth' => '1981-12-31',
          'relationship' => 'Spouse',
          'phone' => '2225555555',
          'email' => 'claimant@example.com'
        },
        'veteran' => {
          'name' => {
            'first' => 'John',
            'middle' => 'M',
            'last' => 'Veteran'
          },
          'address' => {
            'addressLine1' => '123 Fake Veteran St',
            'addressLine2' => 'Apt 1',
            'city' => 'Portland',
            'stateCode' => 'OR',
            'country' => 'US',
            'zipCode' => '12345',
            'zipCodeSuffix' => '6789'
          },
          'ssn' => '123456789',
          'vaFileNumber' => '987654321',
          'dateOfBirth' => '1980-12-31',
          'serviceNumber' => '123123123',
          'serviceBranch' => 'ARMY',
          'phone' => '5555555555',
          'email' => 'veteran@example.com'
        }
      }
    end
    let(:organization) { create(:organization, poa: 'B12') }
    let(:poa_code) { organization.poa }
    let(:representative) { create(:representative, representative_id: '86753') }
    let(:registration_number) { representative.representative_id }

    it 'creates a new AccreditedRepresentativePortal::PowerOfAttorneyRequest' do
      expect { subject.call }.to change(AccreditedRepresentativePortal::PowerOfAttorneyRequest, :count).by(1)
    end

    it 'creates a new AccreditedRepresentativePortal::PowerOfAttorneyForm' do
      expect { subject.call }.to change(AccreditedRepresentativePortal::PowerOfAttorneyForm, :count).by(1)
    end

    it 'sets the claimant' do
      result = subject.call

      expect(result[:request].claimant).to eq(claimant)
    end

    it 'sets the accredited_organization' do
      result = subject.call

      expect(result[:request].accredited_organization).to eq(organization)
    end

    it 'sets the accredited_individual' do
      result = subject.call

      expect(result[:request].accredited_individual).to eq(representative)
    end

    it 'sets the power_of_attorney_holder_type' do
      result = subject.call

      expect(result[:request].power_of_attorney_holder_type).to eq('veteran_service_organization')
    end

    context 'when only poa_code is provided' do
      let(:registration_number) { nil }

      it 'does not set the accredited_individual' do
        result = subject.call

        expect(result[:request].accredited_individual).to be_nil
      end
    end

    context 'when there are errors' do
      context 'when the poa_code is nil' do
        let(:poa_code) { nil }

        it 'returns a meaningful error' do
          result = subject.call

          message = AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Create::ACCREDITED_ENTITY_ERROR

          expect(result[:errors]).to eq([message])
        end

        it 'does not create new records' do
          expect { subject.call }.not_to change(AccreditedRepresentativePortal::PowerOfAttorneyRequest, :count)
          expect { subject.call }.not_to change(AccreditedRepresentativePortal::PowerOfAttorneyForm, :count)
        end
      end

      context 'when the transaction fails' do
        context 'when form data does not pass validation' do
          it 'does not create new records' do
            form_data.delete('authorizations')

            expect { subject.call }.not_to change(AccreditedRepresentativePortal::PowerOfAttorneyRequest, :count)
            expect { subject.call }.not_to change(AccreditedRepresentativePortal::PowerOfAttorneyForm, :count)
          end

          it 'returns a meaningful error' do
            form_data.delete('authorizations')

            error_message = 'Validation failed: Power of attorney form data does not comply with schema'

            result = subject.call

            expect(result[:errors]).to eq([error_message])
          end
        end

        context 'when the request data does not pass validation' do
          let(:claimant) { nil }

          it 'does not create new records' do
            expect { subject.call }.not_to change(AccreditedRepresentativePortal::PowerOfAttorneyRequest, :count)
            expect { subject.call }.not_to change(AccreditedRepresentativePortal::PowerOfAttorneyForm, :count)
          end

          it 'returns a meaningful error' do
            result = subject.call

            expect(result[:errors]).to eq(['Validation failed: Claimant must exist'])
          end
        end
      end
    end
  end
end
