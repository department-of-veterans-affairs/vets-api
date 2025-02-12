# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PowerOfAttorneyRequestService::Create do
  describe '#call' do
    subject do
      described_class.new(claimant: claimant, form_data: form_data, holder_type: holder_type, poa_code: poa_code,
                          registration_number: registration_number)
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
    let(:holder_type) { 'AccreditedOrganization' }
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

    it 'sets the power_of_attorney_holder_type type' do
      result = subject.call

      expect(result[:request].power_of_attorney_holder_type).to eq(holder_type)
    end

    context 'when only registration_number is provided' do
      let(:poa_code) { nil }

      it 'does not set the accredited_organization' do
        result = subject.call

        expect(result[:request].accredited_organization).to be_nil
      end
    end

    context 'when only poa_code is provided' do
      let(:registration_number) { nil }

      it 'does not set the accredited_individual' do
        result = subject.call

        expect(result[:request].accredited_individual).to be_nil
      end
    end

    context 'when there are errors' do
      context 'when both accredited_entity params are nil' do
        let(:registration_number) { nil }
        let(:poa_code) { nil }

        it 'returns a meaningful error' do
          result = subject.call

          expect(result[:errors]).to eq([PowerOfAttorneyRequestService::Create::ACCREDITED_ENTITY_ERROR])
        end

        it 'does not create new records' do
          expect { subject.call }.not_to change(AccreditedRepresentativePortal::PowerOfAttorneyRequest, :count)
          expect { subject.call }.not_to change(AccreditedRepresentativePortal::PowerOfAttorneyForm, :count)
        end
      end

      context 'when the holder_type is not in the allowed list' do
        let(:holder_type) { 'testing' }

        it 'returns a meaningful error' do
          result = subject.call

          expect(result[:errors]).to eq([PowerOfAttorneyRequestService::Create::HOLDER_TYPE_ERROR])
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
