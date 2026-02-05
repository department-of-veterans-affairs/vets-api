# frozen_string_literal: true

require 'rails_helper'
require_relative '../../spec_helper'
require 'sidekiq/testing'

RSpec.describe AccreditedRepresentativePortal::ExpirePowerOfAttorneyRequestsJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  let(:job) { described_class.new }
  let(:expiry_duration) { AccreditedRepresentativePortal::PowerOfAttorneyRequest::EXPIRY_DURATION }
  let!(:claimant) { create(:user_account) }

  def create_request(created_at_time:, claimant_user:, trait: :unresolved)
    travel_to created_at_time do
      create(:power_of_attorney_request, trait, claimant: claimant_user)
    end
  end

  around do |example|
    Sidekiq::Testing.inline! do
      example.run
    end
  end

  describe '#perform' do
    let!(:request_old_unresolved) do
      create_request(created_at_time: (expiry_duration + 1.day).ago, claimant_user: claimant)
    end
    let!(:request_new_unresolved) do
      create_request(created_at_time: (expiry_duration - 1.day).ago, claimant_user: claimant)
    end
    let!(:request_old_accepted) do
      create_request(trait: :with_acceptance, created_at_time: (expiry_duration + 1.day).ago, claimant_user: claimant)
    end
    let!(:request_old_declined) do
      create_request(trait: :with_declination, created_at_time: (expiry_duration + 1.day).ago, claimant_user: claimant)
    end
    let!(:request_just_expired) do
      # Exactly on the boundary (should be expired)
      create_request(created_at_time: expiry_duration.ago, claimant_user: claimant)
    end

    it 'expires only unresolved requests older than the expiry duration' do
      # Verify initial states
      expect(request_old_unresolved).to be_unresolved
      expect(request_new_unresolved).to be_unresolved
      expect(request_old_accepted).to be_resolved
      expect(request_old_declined).to be_resolved
      expect(request_just_expired).to be_unresolved

      # old_unresolved and just_expired
      expect do
        job.perform
      end.to change(AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution, :count).by(2)
      # Reload records to get updated state
      request_old_unresolved.reload
      request_new_unresolved.reload
      request_old_accepted.reload
      request_old_declined.reload
      request_just_expired.reload

      # Assert final states
      expect(request_old_unresolved).to be_resolved
      expect(request_old_unresolved).to be_expired
      expect(request_old_unresolved.resolution.resolving)
        .to be_a(AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration)

      expect(request_just_expired).to be_resolved
      expect(request_just_expired).to be_expired
      expect(request_just_expired.resolution.resolving)
        .to be_a(AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration)

      expect(request_new_unresolved).to be_unresolved # Should not be touched

      expect(request_old_accepted).to be_resolved
      expect(request_old_accepted).to be_accepted # Should still be accepted
      expect(request_old_accepted.resolution.resolving)
        .to be_a(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision)
      expect(request_old_accepted.resolution.resolving.type)
        .to eq(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::ACCEPTANCE)

      expect(request_old_declined).to be_resolved
      expect(request_old_declined).to be_declined # Should still be declined
      expect(request_old_declined.resolution.resolving)
        .to be_a(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision)
      expect(request_old_declined.resolution.resolving.type)
        .to eq(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::DECLINATION)
    end

    it 'does nothing if there are no unresolved old requests' do
      # Delete the eligible request created in the main let block
      request_old_unresolved.power_of_attorney_form&.destroy
      request_old_unresolved.destroy!
      request_just_expired.power_of_attorney_form&.destroy
      request_just_expired.destroy!

      expect { job.perform }.not_to(change(AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution, :count))

      expect(request_new_unresolved.reload).to be_unresolved
      expect(request_old_accepted.reload).to be_accepted
      expect(request_old_declined.reload).to be_declined
    end

    it 'logs the start and end of the job' do
      log_output = StringIO.new
      original_logger = Rails.logger
      Rails.logger = Logger.new(log_output)

      job.perform

      Rails.logger = original_logger

      log_content = log_output.string
      expect(log_content).to include("#{described_class.name}: Starting job.")
      expect(log_content).to include("#{described_class.name}: Finished job. Expired 2 requests. Encountered 0 errors.")
    end

    context 'when an error occurs during expiration' do
      let!(:request_error) do
        create_request(created_at_time: (expiry_duration + 2.days).ago, claimant_user: claimant)
      end

      before do
        allow(AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution).to receive(:create_with_resolving!)
          .and_call_original
        allow(AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution).to receive(:create_with_resolving!)
          .with(hash_including(power_of_attorney_request: request_error))
          .and_raise(StandardError, 'Test DB error')
      end

      it 'logs the error and continues processing other requests' do
        log_output = StringIO.new
        original_logger = Rails.logger
        Rails.logger = Logger.new(log_output)

        # old_unresolved and just_expired still succeed
        expect do
          job.perform
        end.to change(AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution, :count).by(2)
        Rails.logger = original_logger

        log_content = log_output.string

        expect(log_content).to include('Failed to expire PowerOfAttorneyRequest ' \
                                       "##{request_error.id}. Error: Test DB error")
        expect(log_content).to include("#{described_class.name}: Finished job. Expired 2 requests. " \
                                       'Encountered 1 errors.')

        expect(request_error.reload).to be_unresolved
        expect(request_old_unresolved.reload).to be_expired
        expect(request_just_expired.reload).to be_expired
        expect(request_new_unresolved.reload).to be_unresolved
      end
    end

    context 'metrics' do
      let(:monitor_double) do
        instance_double(
          AccreditedRepresentativePortal::Monitoring,
          track_duration: true,
          track_count: true
        )
      end

      before do
        # Ensure a consistent POA code for tag assertions (covers reloaded records too)
        allow_any_instance_of(AccreditedRepresentativePortal::PowerOfAttorneyRequest)
          .to receive(:power_of_attorney_holder_poa_code)
          .and_return('YHZ')

        allow(AccreditedRepresentativePortal::Monitoring).to receive(:new)
          .with(
            'accredited-representative-portal',
            default_tags: ['job:expire_power_of_attorney_requests']
          )
          .and_return(monitor_double)
      end

      it 'emits duration and count metrics with expected tags for each expired request, and memoizes monitor' do
        expect(request_old_unresolved).to be_unresolved
        expect(request_just_expired).to be_unresolved

        job.perform

        expect(AccreditedRepresentativePortal::Monitoring).to have_received(:new).once

        expected_tags = array_including(
          'resolution:expired',
          'source:expire_job',
          'poa_code:YHZ'
        )

        expect(monitor_double).to have_received(:track_duration).with(
          'vets_api.statsd.ar_poa_request_duration',
          from: request_old_unresolved.created_at,
          tags: expected_tags
        )
        expect(monitor_double).to have_received(:track_duration).with(
          'vets_api.statsd.ar_poa_request_duration',
          from: request_just_expired.created_at,
          tags: expected_tags
        )

        expect(monitor_double).to have_received(:track_count).with(
          'ar.poa.request.expired',
          tags: expected_tags
        ).twice
      end
    end
  end
end
