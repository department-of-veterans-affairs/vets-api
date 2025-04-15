# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe PowerOfAttorneyRequests::SendExpiredEmailJob, type: :job do
  describe 'modules and initialization' do
    it 'includes Sidekiq::Job' do
      expect(described_class.included_modules).to include(Sidekiq::Job)
    end
  end

  describe '#perform' do
    context 'when there are no requests' do
      it 'does not queue any emails' do
        expect { subject.perform }.not_to raise_error
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob.jobs).to be_empty
      end
    end

    context 'when there are requests on the expiration date' do
      let!(:request) { create(:power_of_attorney_request, created_at: 60.5.days.ago) }

      it 'queues an email for each request' do
        expect { subject.perform }.not_to raise_error
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob.jobs.size).to eq(1)
      end
    end

    context 'when there are requests on the expiration date with existing notifications' do
      let!(:request) { create(:power_of_attorney_request, created_at: 60.5.days.ago) }
      let!(:notification) do
        create(:power_of_attorney_request_notification, power_of_attorney_request: request, type: 'expired')
      end

      it 'does not queue any emails' do
        expect { subject.perform }.not_to raise_error
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob.jobs).to be_empty
      end
    end

    context 'when there are requests before expiration date' do
      let!(:request) { create(:power_of_attorney_request, created_at: 59.days.ago) }

      it 'does not queue any emails' do
        expect { subject.perform }.not_to raise_error
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob.jobs).to be_empty
      end
    end

    context 'when there are requests after expiration date' do
      let!(:request) { create(:power_of_attorney_request, created_at: 61.days.ago) }

      it 'does not queue any emails' do
        expect { subject.perform }.not_to raise_error
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob.jobs).to be_empty
      end
    end
  end
end
