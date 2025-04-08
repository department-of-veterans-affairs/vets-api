# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe PowerOfAttorneyRequests::SendExpirationReminderEmailJob, type: :job do
  describe 'modules and initialization' do
    it 'includes Sidekiq::Job' do
      expect(described_class.included_modules).to include(Sidekiq::Job)
    end
  end

  describe '#perform' do
    context 'when there are no requests in the reminder range' do
      it 'does not queue any emails' do
        expect { subject.perform }.not_to raise_error
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob.jobs).to be_empty
      end
    end

    context 'when there are requests in the reminder range' do
      let!(:request) { create(:power_of_attorney_request, created_at: 30.5.days.ago) }

      it 'queues an email for each request' do
        expect { subject.perform }.not_to raise_error
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob.jobs.size).to eq(1)
      end
    end

    context 'when there are requests before the reminder range' do
      let!(:request) { create(:power_of_attorney_request, created_at: 31.days.ago) }

      it 'does not queue any emails' do
        expect { subject.perform }.not_to raise_error
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob.jobs).to be_empty
      end
    end

    context 'when there are requests after the reminder range' do
      let!(:request) { create(:power_of_attorney_request, created_at: 29.days.ago) }

      it 'does not queue any emails' do
        expect { subject.perform }.not_to raise_error
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob.jobs).to be_empty
      end
    end
  end
end
