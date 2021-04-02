# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::EnrollmentProcessor do
  subject do
    described_class.new
  end

  let(:records) do
    subs = YAML.load_file('modules/covid_vaccine/spec/fixtures/expanded_registration_submissions.yml')
    subs.values.map do |s|
      FactoryBot.create(:covid_vax_expanded_registration, state: 'received', raw_form_data: s['raw_form_data'])
    end
  end

  around do |example|
    Timecop.freeze(Time.zone.parse('2021-04-02T00:00:00Z'))
    example.run
    Timecop.return
  end

  context 'EnrollmentProcessor#generated_file_name' do
    it 'builds a file_name based on default prefix' do
      expect(subject.generated_file_name(1)).to eq('DHS_load_20210402000000_SLA_1_records.txt')
    end

    it 'builds a file_name based on custom prefix' do
      expect(described_class.new(prefix: 'TEST').generated_file_name(1)).to eq('TEST_20210402000000_SLA_1_records.txt')
    end
  end

  describe '#batch_records!' do
    it 'changes records having state to have batch id' do
      records
      batched_records = subject.batch_records!
      expect(batched_records.size).to eq(records.size)
      expect(batched_records.all.map(&:batch_id)).to all(eq('20210402000000'))
    end
  end

  describe '#process_and_upload with success' do
    it 'updates the state to reflect pending' do
      records
      allow_any_instance_of(CovidVaccine::V0::EnrollmentUploadService)
        .to receive(:upload).and_return(true)
      expect(subject.process_and_upload!).to eq(12)
      batch_ids_and_states = CovidVaccine::V0::ExpandedRegistrationSubmission.all.map do |s|
        [s.batch_id, s.state]
      end
      expect(batch_ids_and_states).to all(eq(%w[20210402000000 enrollment_pending]))
    end
  end

  describe '#process_and_upload with server error' do
    it 'does not update the state' do
      records
      allow_any_instance_of(CovidVaccine::V0::EnrollmentUploadService)
        .to receive(:upload).and_raise(StandardError)
      expect { subject.process_and_upload! }.to raise_error(StandardError)
      batch_ids_and_states = CovidVaccine::V0::ExpandedRegistrationSubmission.all.map do |s|
        [s.batch_id, s.state]
      end
      expect(batch_ids_and_states).to all(eq(%w[20210402000000 received]))
    end
  end
end
