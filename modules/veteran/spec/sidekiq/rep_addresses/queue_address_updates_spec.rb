# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

# Test suite for RepAddresses::QueueAddressUpdates.
# Tests focus on both the observable outcomes of methods and the direct testing of Sentry logging.
RSpec.describe RepAddresses::QueueAddressUpdates, type: :job do
  describe '#perform' do
    let(:mock_file_content) { 'mock file content' }

    before do
      allow_any_instance_of(RepAddresses::XlsxFileFetcher).to receive(:fetch).and_return(mock_file_content)
    end

    # Tests for when file content is available and ensures that process_file is called.
    context 'when file content is available' do
      it 'processes the file' do
        expect_any_instance_of(described_class).to receive(:process_file).with(mock_file_content)
        subject.perform
      end
    end

    # Tests error handling for unavailable file content, including Sentry logging and side effects.
    context 'when file content is unavailable' do
      it 'logs an error and returns early' do
        allow_any_instance_of(RepAddresses::XlsxFileFetcher).to receive(:fetch).and_return(nil)
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(
          'QueueAddressUpdates error: Failed to fetch file or file content is empty', :error
        )
        subject.perform
        expect(RepAddresses::UpdateAddresses.jobs).to be_empty
      end
    end
  end

  describe '#process_file' do
    let(:file_path) { 'modules/veteran/spec/fixtures/xlsx_files/rep-org-addresses-mock-data.xlsx' }

    # Tests that each sheet in the file is processed correctly, focusing on the outcome of enqueuing jobs.
    context 'when processing valid file content' do
      it 'processes each sheet correctly' do
        file_content = File.read(file_path)
        subject.send(:process_file, file_content)
        RepAddresses::QueueAddressUpdates::SHEETS_TO_PROCESS.each do |_sheet_name|
          # rubocop:disable Style/NumericPredicate
          expect(RepAddresses::UpdateAddresses.jobs.size).to be > 0
          # rubocop:enable Style/NumericPredicate
        end
      end
    end

    # Tests error handling for issues during file processing, including Sentry logging and side effects.
    context 'when there is an error processing the file' do
      it 'logs an error' do
        allow(Roo::Spreadsheet).to receive(:open).and_raise(Roo::Error.new('Test error'))
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(
          'QueueAddressUpdates error: Error opening spreadsheet: Test error', :error
        )
        file_content = File.read(file_path)
        subject.send(:process_file, file_content)
        expect(RepAddresses::UpdateAddresses.jobs).to be_empty
      end
    end
  end

  # Additional test contexts will be added after verification in staging.
  # These will cover data transformation and utility methods.
  describe 'Data transformation methods' do
    # ...
  end

  describe 'Utility methods' do
    # ...
  end
end
