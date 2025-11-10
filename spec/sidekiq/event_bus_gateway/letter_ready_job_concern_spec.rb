# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/sidekiq/event_bus_gateway/letter_ready_job_concern'
require_relative '../../../app/sidekiq/event_bus_gateway/constants'

RSpec.describe EventBusGateway::LetterReadyJobConcern, type: :job do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include EventBusGateway::LetterReadyJobConcern
      
      # Define the constant that the concern expects
      const_set(:STATSD_METRIC_PREFIX, 'test_job')
    end
  end

  let(:test_instance) { test_class.new }
  let(:participant_id) { '1234567890' }
  let(:error_message) { 'Test error message' }
  let(:notification_type) { 'Email' }

  let(:bgs_profile) do
    {
      first_nm: 'John',
      last_nm: 'Doe',
      brthdy_dt: 30.years.ago,
      ssn_nbr: '123456789'
    }
  end

  let(:mpi_profile) { build(:mpi_profile, icn: '123456789V012345') }
  let(:mpi_profile_response) { create(:find_profile_response, profile: mpi_profile) }
  let(:user_account) { create(:user_account, icn: mpi_profile.icn) }

  # Shared setup to prevent all external service calls
  let(:bgs_service) { instance_double(BGS::PersonWebService) }
  let(:mpi_service) { instance_double(MPI::Service) }

  before do
    # Prevent all BGS and MPI service instantiation throughout the test suite
    allow(BGS::PersonWebService).to receive(:new).and_return(bgs_service)
    allow(MPI::Service).to receive(:new).and_return(mpi_service)
    
    # Default successful responses to prevent errors in unrelated tests
    allow(bgs_service).to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
    allow(mpi_service).to receive(:find_profile_by_attributes).and_return(mpi_profile_response)
    
    # Stub logging and metrics by default
    allow(Rails.logger).to receive(:error)
    allow(StatsD).to receive(:increment)
  end

  describe '#get_bgs_person' do
    context 'when BGS service returns person data' do
      before do
        allow(bgs_service).to receive(:find_person_by_ptcpnt_id).with(participant_id).and_return(bgs_profile)
      end

      it 'returns the person data' do
        result = test_instance.send(:get_bgs_person, participant_id)
        expect(result).to eq(bgs_profile)
      end

      it 'calls BGS service with correct participant ID' do
        expect(bgs_service).to receive(:find_person_by_ptcpnt_id).with(participant_id)
        test_instance.send(:get_bgs_person, participant_id)
      end
    end

    context 'when BGS service does not return person data' do
      before do
        allow(bgs_service).to receive(:find_person_by_ptcpnt_id).and_return(nil)
      end

      it 'raises the correct error message' do
        expect { test_instance.send(:get_bgs_person, participant_id) }
          .to raise_error('Participant ID cannot be found in BGS')
      end
    end
  end

  describe '#get_mpi_profile' do
    context 'when MPI service returns profile data' do
      before do
        allow(mpi_service).to receive(:find_profile_by_attributes).and_return(mpi_profile_response)
      end

      it 'returns the profile' do
        result = test_instance.send(:get_mpi_profile, participant_id)
        expect(result).to eq(mpi_profile)
      end

      it 'calls MPI service with correct attributes' do
        expected_attributes = {
          first_name: 'John',
          last_name: 'Doe',
          birth_date: bgs_profile[:brthdy_dt].strftime('%Y%m%d'),
          ssn: '123456789'
        }
        expect(mpi_service).to receive(:find_profile_by_attributes).with(expected_attributes)
        test_instance.send(:get_mpi_profile, participant_id)
      end
    end

    context 'when MPI service returns nil' do
      before do
        allow(mpi_service).to receive(:find_profile_by_attributes).and_return(nil)
      end

      it 'raises the correct error message' do
        expect { test_instance.send(:get_mpi_profile, participant_id) }
          .to raise_error('Failed to fetch MPI profile')
      end
    end
  end

  describe '#record_notification_send_failure' do
    let(:error) { StandardError.new('Notification send failed') }

    before do
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    it 'logs the error with correct format' do
      expect(Rails.logger).to receive(:error).with(
        "LetterReady#{notification_type}Job #{notification_type.downcase} error",
        { message: 'Notification send failed' }
      )

      test_instance.send(:record_notification_send_failure, error, notification_type)
    end

    it 'increments the failure metric with correct tags' do
      expected_tags = EventBusGateway::Constants::DD_TAGS + ["function: LetterReady#{notification_type}Job #{notification_type.downcase} error"]
      expect(StatsD).to receive(:increment).with(
        'test_job.failure',
        tags: expected_tags
      )

      test_instance.send(:record_notification_send_failure, error, notification_type)
    end

    context 'with different notification types' do
      ['Email', 'Push', 'SMS'].each do |type|
        it "handles #{type} notification type correctly" do
          # Ensure the test class constant is accessible in this context
          allow(test_instance.class).to receive(:const_get).with(:STATSD_METRIC_PREFIX).and_return('test_job')
          
          expect(Rails.logger).to receive(:error).with(
            "LetterReady#{type}Job #{type.downcase} error",
            { message: 'Notification send failed' }
          )

          expect(StatsD).to receive(:increment).with(
            'test_job.failure',
            tags: EventBusGateway::Constants::DD_TAGS + ["function: LetterReady#{type}Job #{type.downcase} error"]
          )

          test_instance.send(:record_notification_send_failure, error, type)
        end
      end
    end

    context 'when error_message is not provided' do
      it 'uses the error message from the exception' do
        expect(Rails.logger).to receive(:error).with(
          "LetterReady#{notification_type}Job #{notification_type.downcase} error",
          { message: 'Notification send failed' }
        )

        test_instance.send(:record_notification_send_failure, error, notification_type)
      end
    end
  end

  describe '#user_account' do
    let(:icn) { '123456789V012345' }

    context 'when user account exists' do
      before do
        user_account
      end

      it 'returns the user account' do
        result = test_instance.send(:user_account, icn)
        expect(result).to eq(user_account)
      end

      it 'finds user account by ICN' do
        expect(UserAccount).to receive(:find_by).with(icn: icn).and_return(user_account)
        test_instance.send(:user_account, icn)
      end
    end

    context 'when user account does not exist' do
      it 'returns nil' do
        result = test_instance.send(:user_account, 'nonexistent_icn')
        expect(result).to be_nil
      end
    end
  end
end
