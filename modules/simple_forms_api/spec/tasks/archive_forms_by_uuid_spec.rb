# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe 'simple_forms_api:archive_forms_by_uuid', type: :task do
  let(:task) { Rake::Task['simple_forms_api:archive_forms_by_uuid'] }
  let(:mock_job) { instance_double(SimpleFormsApi::FormRemediation::Jobs::ArchiveBatchProcessingJob) }
  let(:mock_config) { instance_double(SimpleFormsApi::FormRemediation::Configuration::VffConfig) }
  let(:mock_presigned_urls) { ['https://example.com/file1.pdf', 'https://example.com/file2.pdf'] }

  before do
    load File.expand_path('../../lib/tasks/archive_forms_by_uuid.rake', __dir__)
    Rake::Task.define_task(:environment)

    allow(SimpleFormsApi::FormRemediation::Configuration::VffConfig).to receive(:new).and_return(mock_config)
    allow(SimpleFormsApi::FormRemediation::Jobs::ArchiveBatchProcessingJob).to receive(:new).and_return(mock_job)
    allow(mock_job).to receive(:perform).and_return(mock_presigned_urls)

    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
  end

  after { task.reenable }

  context 'when valid UUIDs are provided' do
    let(:uuids) { 'abc-123 def-456' }

    it 'invokes the ArchiveBatchProcessingJob and logs presigned URLs' do
      expect(Rails.logger).to receive(:info).with(
        'Starting ArchiveBatchProcessingJob for UUIDs: abc-123, def-456 using type: remediation'
      )
      expect(Rails.logger).to(
        receive(:info).with('Task successfully completed.')
      )
      task.invoke(uuids)
    end
  end

  context 'when no UUIDs are provided' do
    it 'raises an error' do
      expect { task.invoke(nil) }.to raise_error(Common::Exceptions::ParameterMissing, 'Missing parameter')
    end
  end

  context 'when the task raises an error' do
    let(:uuids) { 'abc-123 def-456' }
    let(:error_message) { 'Something went wrong' }

    before do
      allow(mock_job).to receive(:perform).and_raise(StandardError.new(error_message))
    end

    it 'logs the error and prints an error message' do
      expect(Rails.logger).to receive(:error).with("Error occurred while archiving submissions: #{error_message}")
      expect { task.invoke(uuids) }.to output(/An error occurred. Check logs for more details./).to_stdout
    end
  end
end
