# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::EnrollmentProcessor do
  subject do
    described_class.new(batch_id)
  end

  let(:records) do
    subs = YAML.load_file('modules/covid_vaccine/spec/fixtures/expanded_registration_submissions.yml')
    subs.values.map do |s|
      FactoryBot.create(:covid_vax_expanded_registration, state: 'received', raw_form_data: s['raw_form_data'])
    end
  end

  let(:batch_id) { '20210101123456' }
  let(:batched_records) do
    subs = YAML.load_file('modules/covid_vaccine/spec/fixtures/expanded_registration_submissions.yml')
    subs.values.map do |s|
      FactoryBot.create(:covid_vax_expanded_registration, state: 'received', raw_form_data: s['raw_form_data'],
                                                          batch_id:)
    end
  end

  around do |example|
    Timecop.freeze(Time.zone.parse('2021-04-02T00:00:00Z'))
    example.run
    Timecop.return
  end

  context 'EnrollmentProcessor#generated_file_name' do
    it 'builds a file_name based on default prefix' do
      expect(subject.generated_file_name(1)).to eq('DHS_load_20210101123456_SLA_1_records.txt')
    end
  end

  describe 'self.batch_records!' do
    it 'changes records having state received to have batch id' do
      records
      batch_id = subject.class.batch_records!
      expect(CovidVaccine::V0::ExpandedRegistrationSubmission.where(batch_id:).count).to eq(records.size)
    end
  end

  describe '#process_and_upload with success' do
    it 'updates the state to reflect pending' do
      batched_records
      allow_any_instance_of(CovidVaccine::V0::EnrollmentUploadService)
        .to receive(:upload).and_return(true)
      expect(subject.process_and_upload!).to eq(12)
      batch_ids_and_states = CovidVaccine::V0::ExpandedRegistrationSubmission.all.map do |s|
        [s.batch_id, s.state]
      end
      expect(batch_ids_and_states).to all(eq([batch_id, 'enrollment_pending']))
    end
  end

  describe '#process_and_upload with server error' do
    it 'does not update the state' do
      batched_records
      allow_any_instance_of(CovidVaccine::V0::EnrollmentUploadService)
        .to receive(:upload).and_raise(StandardError)
      expect { subject.process_and_upload! }.to raise_error(StandardError)
      batch_ids_and_states = CovidVaccine::V0::ExpandedRegistrationSubmission.all.map do |s|
        [s.batch_id, s.state]
      end
      expect(batch_ids_and_states).to all(eq([batch_id, 'received']))
    end
  end

  describe 'write_to_file' do
    let(:batch_id) { '20210401010101' }

    before do
      create(:covid_vax_expanded_registration, raw_options: { 'first_name' => 'IncludeMe',
                                                              'preferred_facility' => 'vha_648' },
                                               batch_id:)
      create(:covid_vax_expanded_registration, raw_options: { 'first_name' => 'ExcludeMe',
                                                              'preferred_facility' => 'vha_512' },
                                               batch_id: nil)
      create(:covid_vax_expanded_registration, raw_options: { 'first_name' => 'ExcludeMe',
                                                              'preferred_facility' => 'vha_512' },
                                               batch_id: 'other')
    end

    it 'writes records from specified batch to stream' do
      stream = StringIO.new
      CovidVaccine::V0::EnrollmentProcessor.write_to_file(batch_id, stream)
      expect(stream.string).to include('IncludeMe')
      expect(stream.string).to include('^648^')
    end

    it 'ignores records from other batches' do
      stream = StringIO.new
      CovidVaccine::V0::EnrollmentProcessor.write_to_file(batch_id, stream)
      expect(stream.string).not_to include('ExcludeMe')
    end
  end

  describe 'update_state_to_pending' do
    it 'updates state for specified batch_id' do
      batch_id = 'test_batch123'
      record = FactoryBot.create(:covid_vax_expanded_registration, state: 'received', batch_id:)
      CovidVaccine::V0::EnrollmentProcessor.update_state_to_pending(batch_id)
      record.reload
      expect(record).to be_enrollment_pending
    end

    it 'leaves unrelated records alone' do
      batch_id = 'test_batch123'
      record = FactoryBot.create(:covid_vax_expanded_registration, state: 'received', batch_id:)
      CovidVaccine::V0::EnrollmentProcessor.update_state_to_pending('other_batchid')
      record.reload
      expect(record).to be_received
    end

    it 'does not update a nil batch_id' do
      record = FactoryBot.create(:covid_vax_expanded_registration, state: 'received', batch_id: nil)
      CovidVaccine::V0::EnrollmentProcessor.update_state_to_pending(nil)
      record.reload
      expect(record).to be_received
    end
  end
end
