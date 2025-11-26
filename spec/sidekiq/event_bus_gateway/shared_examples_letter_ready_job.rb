# frozen_string_literal: true

RSpec.shared_examples 'letter ready job bgs error handling' do |job_type|
  let(:participant_id) { '1234' }
  let(:template_id) { '5678' }
  let(:mpi_profile) { build(:mpi_profile) }
  let(:mpi_profile_response) { create(:find_profile_response, profile: mpi_profile) }

  before do
    allow_any_instance_of(BGS::PersonWebService)
      .to receive(:find_person_by_ptcpnt_id).and_return(nil)
    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
      .and_return(mpi_profile_response)
    allow(Rails.logger).to receive(:error)
    allow(StatsD).to receive(:increment)
  end

  let(:error_message) { "LetterReady#{job_type}Job #{job_type.downcase} error" }
  let(:message_detail) { 'Participant ID cannot be found in BGS' }
  let(:tags) { EventBusGateway::Constants::DD_TAGS + ["function: #{error_message}"] }

  it 'logs the error, increments the statsd metric, and re-raises for retry' do
    expect(Rails.logger)
      .to receive(:error)
      .with(error_message, { message: message_detail })
    expect(StatsD).to receive(:increment).with("#{described_class::STATSD_METRIC_PREFIX}.failure", tags:)
    expect do
      described_class.new.perform(participant_id, template_id)
    end.to raise_error(EventBusGateway::Errors::BgsPersonNotFoundError, message_detail)
  end
end

RSpec.shared_examples 'letter ready job mpi error handling' do |job_type|
  let(:participant_id) { '1234' }
  let(:template_id) { '5678' }
  let(:bgs_profile) do
    {
      first_nm: 'Joe',
      last_nm: 'Smith',
      brthdy_dt: 30.years.ago,
      ssn_nbr: '123456789'
    }
  end

  before do
    expect_any_instance_of(BGS::PersonWebService)
      .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
      .and_return(nil)
    allow(Rails.logger).to receive(:error)
    allow(StatsD).to receive(:increment)
  end

  let(:error_message) { "LetterReady#{job_type}Job #{job_type.downcase} error" }
  let(:message_detail) { 'Failed to fetch MPI profile' }
  let(:tags) { EventBusGateway::Constants::DD_TAGS + ["function: #{error_message}"] }

  it 'logs the error, increments the statsd metric, and re-raises for retry' do
    expect(Rails.logger)
      .to receive(:error)
      .with(error_message, { message: message_detail })
    expect(StatsD).to receive(:increment).with("#{described_class::STATSD_METRIC_PREFIX}.failure", tags:)
    expect do
      described_class.new.perform(participant_id, template_id)
    end.to raise_error(EventBusGateway::Errors::MpiProfileNotFoundError, message_detail)
  end
end

RSpec.shared_examples 'letter ready job sidekiq retries exhausted' do |job_type|
  context 'when sidekiq retries are exhausted' do
    before do
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    let(:job_id) { 'test-job-id-123' }
    let(:error_class) { 'StandardError' }
    let(:error_message) { 'Some error message' }
    let(:msg) do
      {
        'jid' => job_id,
        'error_class' => error_class,
        'error_message' => error_message
      }
    end
    let(:exception) { StandardError.new(error_message) }

    it 'logs the exhausted retries and increments the statsd metric' do
      # Get the retries exhausted callback from the job class
      retries_exhausted_callback = described_class.sidekiq_retries_exhausted_block

      expect(Rails.logger).to receive(:error)
        .with("LetterReady#{job_type}Job retries exhausted", {
                job_id:,
                timestamp: be_within(1.second).of(Time.now.utc),
                error_class:,
                error_message:
              })

      expect(StatsD).to receive(:increment)
        .with("#{described_class::STATSD_METRIC_PREFIX}.exhausted",
              tags: EventBusGateway::Constants::DD_TAGS + ["function: #{error_message}"])

      retries_exhausted_callback.call(msg, exception)
    end
  end
end

RSpec.shared_examples 'letter ready job va notify error handling' do |job_type|
  let(:participant_id) { '1234' }
  let(:template_id) { '5678' }
  let(:bgs_profile) do
    {
      first_nm: 'Joe',
      last_nm: 'Smith',
      brthdy_dt: 30.years.ago,
      ssn_nbr: '123456789'
    }
  end
  let(:mpi_profile) { build(:mpi_profile) }
  let(:mpi_profile_response) { create(:find_profile_response, profile: mpi_profile) }

  context 'when a VA Notify error occurs' do
    before do
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    let(:error_message) { "LetterReady#{job_type}Job #{job_type.downcase} error" }
    let(:message_detail) { 'Service initialization failed' }
    let(:tags) { EventBusGateway::Constants::DD_TAGS + ["function: #{error_message}"] }

    it 'raises and logs the error, and increments the statsd metric' do
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: message_detail })
      expect(StatsD).to receive(:increment).with("#{described_class::STATSD_METRIC_PREFIX}.failure", tags:)
      expect do
        described_class.new.perform(participant_id, template_id)
      end.to raise_error(StandardError)
    end
  end
end
