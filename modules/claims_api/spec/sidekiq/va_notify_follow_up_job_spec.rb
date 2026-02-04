# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::VANotifyFollowUpJob, type: :job do
  subject { described_class.new }

  describe '#perform' do
    before do
      allow_any_instance_of(described_class).to receive(:handle_failure).and_return(true)
    end

    let(:notification_id) { '111111-1111-1111-11111111' }
    let(:temp) { create(:power_of_attorney, :with_full_headers) }

    context 'queue up the job' do
      before do
        allow_any_instance_of(described_class).to receive(:notification_response_status).and_return('delivered')
      end

      it 'queues up with just the notification_id' do
        expect do
          subject.perform(notification_id)
        end.not_to raise_error
      end

      it 'queues up with notification_id and poa_id' do
        expect do
          subject.perform(notification_id, temp.id)
        end.not_to raise_error
      end

      it 'throws an argument error when other params are added' do
        expect do
          subject.perform(notification_id, 'status_id', temp.id)
        end.to raise_error(ArgumentError)
      end
    end

    context 'no retry statues' do
      shared_examples 'does not requeue the job' do |status|
        it "when the status is #{status}" do
          power_of_attorney = ClaimsApi::PowerOfAttorney.find(temp.id)
          allow(ClaimsApi::PowerOfAttorney).to receive(:find).with(temp.id).and_return(power_of_attorney)
          allow(described_class).to receive(:perform_async)
          allow_any_instance_of(described_class).to receive(:notification_response_status).and_return(status)

          subject.perform(notification_id, power_of_attorney.id)

          expect(described_class).not_to have_received(:perform_async)
        end
      end

      described_class::NON_RETRY_STATUSES.each do |status|
        include_examples 'does not requeue the job', status.to_s
      end
    end

    context 'retry statues' do
      shared_examples 'requeues the job' do |status|
        it "when the status is #{status}" do
          power_of_attorney = ClaimsApi::PowerOfAttorney.find(temp.id)
          allow(ClaimsApi::PowerOfAttorney).to receive(:find).with(temp.id).and_return(power_of_attorney)
          allow_any_instance_of(described_class).to receive(:notification_response_status).and_return(status)
          expect do
            subject.perform(notification_id, power_of_attorney.id)
          end.to raise_error(
            RuntimeError,
            "Status for notification #{notification_id} was '#{status}'. POA ID: #{power_of_attorney.id}"
          )
        end
      end

      described_class::RETRY_STATUSES.each do |status|
        include_examples 'requeues the job', status.to_s
      end
    end

    context 'logging for completion status' do
      shared_examples 'does not requeue the job' do |status|
        it "when the status is #{status}" do
          power_of_attorney = ClaimsApi::PowerOfAttorney.find(temp.id)
          allow(ClaimsApi::PowerOfAttorney).to receive(:find).with(temp.id).and_return(power_of_attorney)
          allow(described_class).to receive(:perform_async)
          allow_any_instance_of(described_class).to receive(:notification_response_status).and_return(status)

          subject.perform(notification_id, power_of_attorney.id)

          expect(described_class).not_to have_received(:perform_async)
          process = ClaimsApi::Process.find_by(processable: power_of_attorney, step_type: 'CLAIMANT_NOTIFICATION')
          expect(process.completed_at).not_to be_nil
        end
      end

      described_class::NON_RETRY_STATUSES.each do |status|
        include_examples 'does not requeue the job', status.to_s
      end
    end

    # context 'logging for not completed status' do
    context 'logging for not completed status' do
      shared_examples 'requeues the job' do |status|
        it "when the status is #{status}" do
          power_of_attorney = ClaimsApi::PowerOfAttorney.find(temp.id)
          allow(ClaimsApi::PowerOfAttorney).to receive(:find).with(temp.id).and_return(power_of_attorney)
          allow_any_instance_of(described_class).to receive(:notification_response_status).and_return(status)
          expect do
            subject.perform(notification_id, power_of_attorney.id)
          end.to raise_error(
            RuntimeError,
            "Status for notification #{notification_id} was '#{status}'. POA ID: #{power_of_attorney.id}"
          )
          process = ClaimsApi::Process.find_by(processable: power_of_attorney, step_type: 'CLAIMANT_NOTIFICATION')
          expect(process.completed_at).to be_nil
        end
      end

      described_class::RETRY_STATUSES.each do |status|
        include_examples 'requeues the job', status.to_s
      end
    end
  end
end
