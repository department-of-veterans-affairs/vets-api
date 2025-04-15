# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::PowerOfAttorneyRequestService::Orchestrate do
  describe '#call' do
    subject do
      described_class.new(data:, dependent:, service_branch:, user:)
    end

    let(:user) { create(:user, :loa3) }
    let!(:user_verification) { create(:idme_user_verification, idme_uuid: user.idme_uuid) }
    let(:organization) { create(:organization, poa: 'B12') }
    let(:representative) { create(:representative, representative_id: '86753') }
    let(:dependent) { true }
    let(:service_branch) { 'ARMY' }
    let(:data) do
      {
        record_consent: true,
        consent_limits: ['HIV'],
        consent_address_change: true,
        veteran_first_name: 'John',
        veteran_middle_initial: 'M',
        veteran_last_name: 'Veteran',
        veteran_social_security_number: '123456789',
        veteran_va_file_number: '987654321',
        veteran_date_of_birth: '1980-12-31',
        veteran_service_number: '123123123',
        veteran_address_line1: '123 Fake Veteran St',
        veteran_address_line2: 'Apt 1',
        veteran_city: 'Portland',
        veteran_state_code: 'OR',
        veteran_country: 'US',
        veteran_zip_code: '12345',
        veteran_zip_code_suffix: '6789',
        veteran_phone: '5555555555',
        veteran_email: 'veteran@example.com',
        claimant_first_name: 'Bob',
        claimant_middle_initial: 'E',
        claimant_last_name: 'Claimant',
        claimant_date_of_birth: '1981-12-31',
        claimant_relationship: 'Spouse',
        claimant_address_line1: '123 Fake Claimant St',
        claimant_address_line2: 'Apt 2',
        claimant_city: 'Eugene',
        claimant_state_code: 'OR',
        claimant_country: 'US',
        claimant_zip_code: '54321',
        claimant_zip_code_suffix: '9876',
        claimant_phone: '2225555555',
        claimant_email: 'claimant@example.com',
        organization_id: organization.poa,
        representative_id: representative.representative_id
      }
    end

    it 'creates a new AccreditedRepresentativePortal::PowerOfAttorneyRequest' do
      expect { subject.call }.to change(AccreditedRepresentativePortal::PowerOfAttorneyRequest, :count).by(1)
    end

    it 'creates a new AccreditedRepresentativePortal::PowerOfAttorneyForm' do
      expect { subject.call }.to change(AccreditedRepresentativePortal::PowerOfAttorneyForm, :count).by(1)
    end

    it 'enqueues a AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob' do
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob).to receive(:perform_async)
      subject.call
    end

    context 'when there is a form in progress' do
      let!(:form) { create(:in_progress_form, user_account: user.user_account, form_id: '21-22') }

      it 'destroys the form' do
        expect { subject.call }.to change(InProgressForm, :count).by(-1)
      end
    end

    context 'when there is no form in progress' do
      it 'does not destroy a form' do
        expect { subject.call }.not_to change(InProgressForm, :count)
      end
    end

    it 'returns a PowerOfAttorneyRequest' do
      result = subject.call

      expect(result[:request]).to be_a(AccreditedRepresentativePortal::PowerOfAttorneyRequest)
    end

    context 'when there is an error' do
      before do
        data[:record_consent] = 'abc'
      end

      it 'returns a meaningful error message' do
        result = subject.call

        expect(result[:errors]).to eq(['value at `/authorizations/recordDisclosure` is not a boolean'])
      end

      it 'does not create a new AccreditedRepresentativePortal::PowerOfAttorneyRequest' do
        expect { subject.call }.not_to change(AccreditedRepresentativePortal::PowerOfAttorneyRequest, :count)
      end

      it 'does not create a new AccreditedRepresentativePortal::PowerOfAttorneyForm' do
        expect { subject.call }.not_to change(AccreditedRepresentativePortal::PowerOfAttorneyForm, :count)
      end

      it 'does not enqueue a AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob' do
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob).not_to receive(:perform_async)
        subject.call
      end

      it 'does not attempt to destroy a form in progress' do
        expect(InProgressForm).not_to receive(:form_for_user)

        subject.call
      end
    end

    context 'when there is an error destroying the form' do
      before do
        allow(InProgressForm).to receive(:form_for_user).and_raise(StandardError, 'test')
      end

      it 'adds the test error message' do
        result = subject.call

        expect(result[:errors]).to eq(['test'])
      end

      it 'does enqueue a AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob' do
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob).to receive(:perform_async)
        subject.call
      end
    end
  end
end
