# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe 'simple_forms_api:remediate_0781_and_0781v2_forms', type: :task do
  let(:submission) do
    instance_double(
      Form526Submission,
      id: '123',
      created_at: Time.zone.local(2020, 1, 1, 12, 0, 0),
      submitted_claim_id: 'abc',
      form_to_json: '{"form0781": {"foo": "bar"}, "form0781v2": {"baz": "qux"}}'
    )
  end
  let(:job) { instance_double(SimpleFormsApi::FormRemediation::Jobs::ArchiveBatchProcessingJob) }
  let(:form_json) { { 'form0781' => { 'foo' => 'bar' }, 'form0781v2' => { 'baz' => 'qux' } } }

  before do
    load File.expand_path('../../lib/tasks/remediate_0781_and_0781v2_forms.rake', __dir__)
    Rake::Task.define_task(:environment)
    allow(SimpleFormsApi::FormRemediation::Jobs::ArchiveBatchProcessingJob).to receive(:new).and_return(job)
    allow(job).to receive(:perform)
    allow(Form526Submission).to receive(:find).and_return(submission)
    allow(JSON).to receive(:parse).and_return(form_json)
    allow(StatsD).to receive(:increment)
    allow(StatsD).to receive(:gauge)
    allow(StatsD).to receive(:measure)
    allow(Time).to receive(:current).and_return(Time.zone.now)
  end

  after do
    # Always re-enable the task after a test
    Rake::Task['simple_forms_api:remediate_0781_and_0781v2_forms'].reenable
  end

  it 'processes submissions from a list of IDs' do
    output = capture_stdout do
      Rake::Task['simple_forms_api:remediate_0781_and_0781v2_forms'].invoke('123')
    end

    expect(output).to include('Processing')
    expect(output).to include('Successfully processed')
  end

  it 'handles CSV input files with submission IDs' do
    temp_file = Tempfile.new(['test', '.csv'])
    begin
      temp_file.write("submission_id\n123")
      temp_file.close

      output = capture_stdout do
        Rake::Task['simple_forms_api:remediate_0781_and_0781v2_forms'].reenable
        Rake::Task['simple_forms_api:remediate_0781_and_0781v2_forms'].invoke(temp_file.path)
      end

      expect(output).to include('Processing')
    ensure
      temp_file.unlink
    end
  end

  it 'reports not found for missing submissions' do
    allow(Form526Submission).to receive(:find).and_raise(ActiveRecord::RecordNotFound)

    output = capture_stdout do
      Rake::Task['simple_forms_api:remediate_0781_and_0781v2_forms'].reenable
      Rake::Task['simple_forms_api:remediate_0781_and_0781v2_forms'].invoke('999')
    end

    expect(output).to include('Not found')
  end

  it 'reports errors for unexpected exceptions' do
    allow(Form526Submission).to receive(:find).and_raise(StandardError, 'fail')
    allow(Rails.logger).to receive(:error)

    output = capture_stdout do
      Rake::Task['simple_forms_api:remediate_0781_and_0781v2_forms'].reenable
      Rake::Task['simple_forms_api:remediate_0781_and_0781v2_forms'].invoke('999')
    end

    expect(output).to include('Error')
  end

  it 'skips empty form content' do
    empty_json = { 'form0781' => {}, 'form0781v2' => { 'baz' => 'qux' } }
    allow(JSON).to receive(:parse).and_return(empty_json)

    output = capture_stdout do
      Rake::Task['simple_forms_api:remediate_0781_and_0781v2_forms'].reenable
      Rake::Task['simple_forms_api:remediate_0781_and_0781v2_forms'].invoke('123')
    end

    expect(output).to include('form0781v2')
    expect(output).not_to include('Processing 123 with form form0781 (')
  end

  # Helper method to capture stdout
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
