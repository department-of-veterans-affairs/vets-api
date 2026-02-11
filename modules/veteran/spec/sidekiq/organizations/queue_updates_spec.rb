# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe Organizations::QueueUpdates, type: :job do
  describe 'modules and initialization' do
    it 'includes Sidekiq::Job' do
      expect(described_class.included_modules).to include(Sidekiq::Job)
    end
  end

  describe '#perform' do
    let(:file_content) { 'dummy file content' }
    let(:processed_data) do
      {
        'VSOs' => [{ id: '123', address: {} }]
      }
    end
    let(:batch) { instance_double(Sidekiq::Batch) }

    before do
      stub_const('Sidekiq::Batch', Class.new) unless defined?(Sidekiq::Batch)
      Veteran::Service::Organization.create!(poa: '123', address_line1: '123 Main St')
      allow(Representatives::XlsxFileFetcher).to receive(:new).and_return(double(fetch: file_content))
      allow_any_instance_of(Organizations::XlsxFileProcessor).to receive(:process).and_return(processed_data)
      allow(Sidekiq::Batch).to receive(:new).and_return(batch)
      allow(batch).to receive(:description=)
      allow(batch).to receive(:jobs).and_yield
    end

    context 'when file processing is successful' do
      it 'processes the file and queues updates' do
        expect { subject.perform }.not_to raise_error

        expected_jobs_count = processed_data.keys.size
        expect(Organizations::Update.jobs.size).to eq(expected_jobs_count)
      end
    end

    context 'when fetch_file_content returns nil' do
      before do
        allow_any_instance_of(described_class).to receive(:fetch_file_content).and_return(nil)
      end

      it 'does not process the file or queue updates' do
        expect { subject.perform }.not_to raise_error
        expect(Organizations::Update.jobs).to be_empty
      end
    end

    context 'when an exception is raised' do
      before do
        allow_any_instance_of(Organizations::XlsxFileProcessor).to receive(:process).and_raise(StandardError,
                                                                                               'test error')
        allow_any_instance_of(described_class).to receive(:log_error)
      end

      it 'logs the error' do
        expect { subject.perform }.not_to raise_error
        expect(subject).to have_received(:log_error).with('Error in file fetching process: test error') # rubocop:disable RSpec/SubjectStub
      end
    end
  end
end
