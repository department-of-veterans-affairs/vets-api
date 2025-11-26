# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/sidekiq/event_bus_gateway/letter_ready_job_concern'
require_relative '../../../app/sidekiq/event_bus_gateway/constants'

RSpec.describe EventBusGateway::LetterReadyJobConcern, type: :job do
  let(:test_class) do
    Class.new do
      include EventBusGateway::LetterReadyJobConcern
      const_set(:STATSD_METRIC_PREFIX, 'test_job')
    end
  end

  let(:test_instance) { test_class.new }
  let(:participant_id) { '1234567890' }
  let(:icn) { '123456789V012345' }

  let(:bgs_profile) do
    {
      first_nm: 'John',
      last_nm: 'Doe',
      brthdy_dt: 30.years.ago,
      ssn_nbr: '123456789'
    }
  end

  let(:mpi_profile) { build(:mpi_profile, icn:) }
  let(:mpi_profile_response) { create(:find_profile_response, profile: mpi_profile) }
  let!(:user_account) { create(:user_account, icn: mpi_profile.icn) }

  let(:bgs_service) { instance_double(BGS::PersonWebService) }
  let(:mpi_service) { instance_double(MPI::Service) }

  # Shared setup for most test scenarios
  before do
    allow(BGS::PersonWebService).to receive(:new).and_return(bgs_service)
    allow(MPI::Service).to receive(:new).and_return(mpi_service)
    allow(bgs_service).to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
    allow(mpi_service).to receive(:find_profile_by_attributes).and_return(mpi_profile_response)
    allow(Rails.logger).to receive(:error)
    allow(StatsD).to receive(:increment)
  end

  describe '#get_bgs_person' do
    context 'when BGS service returns person data' do
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
          .to raise_error(EventBusGateway::Errors::BgsPersonNotFoundError, 'Participant ID cannot be found in BGS')
      end
    end
  end

  describe '#get_mpi_profile' do
    context 'when MPI service returns profile data' do
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

    context 'when MPI service returns nil response' do
      before do
        allow(mpi_service).to receive(:find_profile_by_attributes).and_return(nil)
      end

      it 'raises the correct error message' do
        expect { test_instance.send(:get_mpi_profile, participant_id) }
          .to raise_error(EventBusGateway::Errors::MpiProfileNotFoundError, 'Failed to fetch MPI profile')
      end
    end

    context 'when MPI service returns response with nil profile' do
      let(:mpi_profile_response) { create(:find_profile_response, profile: nil) }

      it 'raises the correct error message' do
        expect { test_instance.send(:get_mpi_profile, participant_id) }
          .to raise_error(EventBusGateway::Errors::MpiProfileNotFoundError, 'Failed to fetch MPI profile')
      end
    end
  end

  describe '#record_notification_send_failure' do
    let(:error) { StandardError.new('Notification send failed') }
    let(:notification_type) { 'Email' }

    it 'logs the error with correct format' do
      expect(Rails.logger).to receive(:error).with(
        "LetterReady#{notification_type}Job #{notification_type.downcase} error",
        { message: 'Notification send failed' }
      )
      test_instance.send(:record_notification_send_failure, error, notification_type)
    end

    it 'increments the failure metric with correct tags' do
      expected_tags = EventBusGateway::Constants::DD_TAGS +
                      ["function: LetterReady#{notification_type}Job #{notification_type.downcase} error"]

      expect(StatsD).to receive(:increment).with('test_job.failure', tags: expected_tags)
      test_instance.send(:record_notification_send_failure, error, notification_type)
    end

    context 'with different notification types' do
      %w[Email Push SMS].each do |type|
        it "handles #{type} notification type correctly" do
          expect(Rails.logger).to receive(:error).with(
            "LetterReady#{type}Job #{type.downcase} error",
            { message: 'Notification send failed' }
          )

          expected_tags = EventBusGateway::Constants::DD_TAGS +
                          ["function: LetterReady#{type}Job #{type.downcase} error"]
          expect(StatsD).to receive(:increment).with('test_job.failure', tags: expected_tags)

          test_instance.send(:record_notification_send_failure, error, type)
        end
      end
    end
  end

  describe '#user_account' do
    context 'when user account exists' do
      it 'returns the user account' do
        result = test_instance.send(:user_account, icn)
        expect(result).to eq(user_account)
      end

      it 'finds user account by ICN' do
        expect(UserAccount).to receive(:find_by).with(icn:).and_return(user_account)
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

  describe '#get_first_name_from_participant_id' do
    context 'when BGS person has a first name' do
      it 'returns the capitalized first name' do
        result = test_instance.send(:get_first_name_from_participant_id, participant_id)
        expect(result).to eq('John')
      end
    end

    context 'when BGS person has uppercase first name' do
      let(:bgs_profile) do
        {
          first_nm: 'JANE',
          last_nm: 'DOE',
          brthdy_dt: 30.years.ago,
          ssn_nbr: '123456789'
        }
      end

      it 'returns the properly capitalized first name' do
        result = test_instance.send(:get_first_name_from_participant_id, participant_id)
        expect(result).to eq('Jane')
      end
    end

    shared_examples 'returns appropriate value for missing name' do |expected_value|
      it "returns #{expected_value.inspect}" do
        result = test_instance.send(:get_first_name_from_participant_id, participant_id)
        expect(result).to eq(expected_value)
      end
    end

    context 'when BGS person has nil first name' do
      let(:bgs_profile) do
        {
          first_nm: nil,
          last_nm: 'smith',
          brthdy_dt: 30.years.ago,
          ssn_nbr: '123456789'
        }
      end

      include_examples 'returns appropriate value for missing name', nil
    end

    context 'when BGS person has empty first name' do
      let(:bgs_profile) do
        {
          first_nm: '',
          last_nm: 'smith',
          brthdy_dt: 30.years.ago,
          ssn_nbr: '123456789'
        }
      end

      include_examples 'returns appropriate value for missing name', ''
    end

    context 'when BGS service returns nil' do
      before do
        allow(bgs_service).to receive(:find_person_by_ptcpnt_id).and_return(nil)
      end

      it 'raises error from get_bgs_person' do
        expect do
          test_instance.send(:get_first_name_from_participant_id, participant_id)
        end.to raise_error(EventBusGateway::Errors::BgsPersonNotFoundError, 'Participant ID cannot be found in BGS')
      end
    end

    context 'when BGS service raises an error' do
      before do
        allow(bgs_service).to receive(:find_person_by_ptcpnt_id)
          .and_raise(StandardError, 'BGS service unavailable')
      end

      it 'propagates the BGS error' do
        expect do
          test_instance.send(:get_first_name_from_participant_id, participant_id)
        end.to raise_error(StandardError, 'BGS service unavailable')
      end
    end
  end

  describe '#get_icn' do
    context 'when MPI profile exists with ICN' do
      it 'returns the ICN' do
        result = test_instance.send(:get_icn, participant_id)
        expect(result).to eq(icn)
      end
    end

    context 'when MPI profile has nil ICN' do
      let(:mpi_profile) { build(:mpi_profile, icn: nil) }

      it 'returns nil' do
        result = test_instance.send(:get_icn, participant_id)
        expect(result).to be_nil
      end
    end

    shared_examples 'raises MPI profile error' do |error_message|
      it 'raises error from get_mpi_profile' do
        expect do
          test_instance.send(:get_icn, participant_id)
        end.to raise_error(EventBusGateway::Errors::MpiProfileNotFoundError, error_message)
      end
    end

    context 'when MPI service returns nil profile' do
      before do
        allow(mpi_service).to receive(:find_profile_by_attributes).and_return(nil)
      end

      include_examples 'raises MPI profile error', 'Failed to fetch MPI profile'
    end

    context 'when MPI service returns response with nil profile' do
      let(:mpi_profile_response) { create(:find_profile_response, profile: nil) }

      include_examples 'raises MPI profile error', 'Failed to fetch MPI profile'
    end

    context 'when BGS service fails before MPI lookup' do
      before do
        allow(bgs_service).to receive(:find_person_by_ptcpnt_id).and_return(nil)
      end

      it 'raises BGS error before attempting MPI lookup' do
        expect do
          test_instance.send(:get_icn, participant_id)
        end.to raise_error(EventBusGateway::Errors::BgsPersonNotFoundError, 'Participant ID cannot be found in BGS')
      end
    end

    context 'when MPI service raises an error' do
      before do
        allow(mpi_service).to receive(:find_profile_by_attributes)
          .and_raise(StandardError, 'MPI service timeout')
      end

      it 'propagates the MPI error' do
        expect do
          test_instance.send(:get_icn, participant_id)
        end.to raise_error(StandardError, 'MPI service timeout')
      end
    end
  end

  describe 'method dependencies and caching' do
    let(:fresh_test_instance) { test_class.new }

    before do
      # Use real service initialization for caching tests
      allow(BGS::PersonWebService).to receive(:new).and_call_original
      allow(MPI::Service).to receive(:new).and_call_original
    end

    it 'caches BGS person data to avoid duplicate calls' do
      expect_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id)
        .with(participant_id).once.and_return(bgs_profile)
      expect_any_instance_of(MPI::Service)
        .to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response)

      # Call both methods that depend on get_bgs_person
      fresh_test_instance.send(:get_first_name_from_participant_id, participant_id)
      fresh_test_instance.send(:get_icn, participant_id)
    end

    it 'caches MPI profile data to avoid duplicate calls' do
      expect_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id)
        .and_return(bgs_profile)
      expect_any_instance_of(MPI::Service)
        .to receive(:find_profile_by_attributes)
        .once.and_return(mpi_profile_response)

      # Call get_icn multiple times
      fresh_test_instance.send(:get_icn, participant_id)
      fresh_test_instance.send(:get_icn, participant_id)
    end
  end
end
