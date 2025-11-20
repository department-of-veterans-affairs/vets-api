# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'
require 'unified_health_data/logging'
require 'unified_health_data/models/lab_or_test'

RSpec.describe UnifiedHealthData::Logging do
  let(:user) { build(:user, :loa3) }
  let(:logging) { described_class.new(user) }

  describe '#log_test_code_distribution' do
    let(:ch_record) do
      UnifiedHealthData::LabOrTest.new(
        id: '123',
        type: 'DiagnosticReport',
        display: 'Chemistry Test',
        test_code: 'CH',
        date_completed: '2023-01-01',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )
    end
    let(:sp_record) do
      UnifiedHealthData::LabOrTest.new(
        id: '456',
        type: 'DiagnosticReport',
        display: 'Surgical Pathology Test',
        test_code: 'SP',
        date_completed: '2023-01-01',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )
    end
    let(:cy_record) do
      UnifiedHealthData::LabOrTest.new(
        id: '789',
        type: 'DiagnosticReport',
        display: 'Cytology Test',
        test_code: 'CY',
        date_completed: '2023-01-01',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )
    end
    let(:mb_record) do
      UnifiedHealthData::LabOrTest.new(
        id: '999',
        type: 'DiagnosticReport',
        display: 'Microbiology Test',
        test_code: 'MB',
        date_completed: '2023-01-01',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )
    end

    before do
      allow(Rails.logger).to receive(:info)
    end

    it 'logs test code distribution with counts' do
      # Create a sample set of records with multiple test codes
      records = [ch_record, sp_record, ch_record, cy_record, mb_record, ch_record]

      # Call the method on the logging instance
      logging.log_test_code_distribution(records)

      # Verify that the logger was called with the correct distribution data
      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          message: 'UHD test code and name distribution',
          test_code_distribution: 'CH:3,SP:1,CY:1,MB:1',
          test_name_distribution: 'Chemistry Test:3,Surgical Pathology Test:1,Cytology Test:1,Microbiology Test:1',
          total_codes: 4,
          total_names: 4,
          total_records: 6,
          service: 'unified_health_data'
        )
      )
    end

    it 'logs nothing if no records are present' do
      logging.log_test_code_distribution([])
      expect(Rails.logger).not_to have_received(:info)
    end

    it 'handles records with missing test codes' do
      record_with_no_code = UnifiedHealthData::LabOrTest.new(
        id: '123',
        type: 'DiagnosticReport',
        display: 'Unknown Test',
        test_code: nil,
        date_completed: '2023-01-01',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )

      records = [ch_record, record_with_no_code, sp_record]
      logging.log_test_code_distribution(records)

      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          test_code_distribution: 'CH:1,SP:1',
          test_name_distribution: 'Chemistry Test:1,Unknown Test:1,Surgical Pathology Test:1',
          total_codes: 2,
          total_names: 3,
          total_records: 3
        )
      )
    end

    it 'handles records with missing test names' do
      record_with_no_name = UnifiedHealthData::LabOrTest.new(
        id: '123',
        type: 'DiagnosticReport',
        display: '',
        test_code: 'CH',
        date_completed: '2023-01-01',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )

      records = [ch_record, record_with_no_name, sp_record]
      logging.log_test_code_distribution(records)

      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          test_code_distribution: 'CH:2,SP:1',
          test_name_distribution: 'Chemistry Test:1,Surgical Pathology Test:1',
          total_codes: 2,
          total_names: 2,
          total_records: 3
        )
      )
    end

    it 'handles records with special characters in test names' do
      record_with_special_chars = UnifiedHealthData::LabOrTest.new(
        id: '123',
        type: 'DiagnosticReport',
        display: 'Test: Blood, Chemistry & More',
        test_code: 'CH',
        date_completed: '2023-01-01',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )

      records = [record_with_special_chars, sp_record]
      logging.log_test_code_distribution(records)

      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          test_code_distribution: 'CH:1,SP:1',
          test_name_distribution: 'Test: Blood, Chemistry & More:1,Surgical Pathology Test:1',
          total_codes: 2,
          total_names: 2,
          total_records: 2
        )
      )
    end
  end

  describe '#log_short_test_name_issue' do
    let(:short_name_record) do
      UnifiedHealthData::LabOrTest.new(
        id: '123',
        type: 'DiagnosticReport',
        display: 'CH',
        test_code: 'CH',
        date_completed: '2023-01-01T10:00:00Z',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )
    end

    before do
      allow(PersonalInformationLog).to receive(:create!)
      allow(Rails.logger).to receive(:error)
    end

    it 'creates a PersonalInformationLog when test name is 3 characters or less' do
      expected_data = {
        icn: user.icn,
        test_code: 'CH',
        test_name: 'CH',
        record_id: '123',
        resource_type: 'DiagnosticReport',
        date_completed: '2023-01-01T10:00:00Z',
        service: 'unified_health_data'
      }

      logging.send(:log_short_test_name_issue, short_name_record)

      expect(PersonalInformationLog).to have_received(:create!).with(
        error_class: 'UHD Short Test Name Issue',
        data: expected_data
      )
    end

    it 'handles PersonalInformationLog creation errors gracefully' do
      allow(PersonalInformationLog).to receive(:create!).and_raise(StandardError.new('Test error'))

      expect { logging.send(:log_short_test_name_issue, short_name_record) }.not_to raise_error

      expect(Rails.logger).to have_received(:error).with(
        'Error creating PersonalInformationLog for short test name issue: StandardError',
        hash_including(
          service: 'unified_health_data',
          backtrace: kind_of(Array)
        )
      )
    end
  end

  describe '#count_test_codes_and_names with short name logging' do
    let(:normal_name_record) do
      UnifiedHealthData::LabOrTest.new(
        id: '123',
        type: 'DiagnosticReport',
        display: 'Chemistry Test',
        test_code: 'CH',
        date_completed: '2023-01-01',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )
    end

    let(:short_name_record_ch) do
      UnifiedHealthData::LabOrTest.new(
        id: '456',
        type: 'DiagnosticReport',
        display: 'CH',
        test_code: 'CH',
        date_completed: '2023-01-01',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )
    end

    let(:short_name_record_sp) do
      UnifiedHealthData::LabOrTest.new(
        id: '789',
        type: 'DiagnosticReport',
        display: 'SP',
        test_code: 'SP',
        date_completed: '2023-01-01',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )
    end

    let(:short_name_record_three_chars) do
      UnifiedHealthData::LabOrTest.new(
        id: '999',
        type: 'DiagnosticReport',
        display: 'ABC',
        test_code: 'MB',
        date_completed: '2023-01-01',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )
    end

    before do
      allow(logging).to receive(:log_short_test_name_issue)
    end

    it 'calls log_short_test_name_issue when test name is 2 characters' do
      records = [normal_name_record, short_name_record_ch]

      logging.send(:count_test_codes_and_names, records)

      expect(logging).to have_received(:log_short_test_name_issue).once.with(short_name_record_ch)
    end

    it 'calls log_short_test_name_issue when test name is 3 characters' do
      records = [normal_name_record, short_name_record_three_chars]

      logging.send(:count_test_codes_and_names, records)

      expect(logging).to have_received(:log_short_test_name_issue).once.with(short_name_record_three_chars)
    end

    it 'calls log_short_test_name_issue for multiple short names' do
      records = [normal_name_record, short_name_record_ch, short_name_record_sp, short_name_record_three_chars]

      logging.send(:count_test_codes_and_names, records)

      expect(logging).to have_received(:log_short_test_name_issue).exactly(3).times

      # Verify it was called with records having the expected short names
      expect(logging).to have_received(:log_short_test_name_issue).with(satisfy { |record|
        record.display == 'CH'
      })
      expect(logging).to have_received(:log_short_test_name_issue).with(satisfy { |record|
        record.display == 'SP'
      })
      expect(logging).to have_received(:log_short_test_name_issue).with(satisfy { |record|
        record.display == 'ABC'
      })
    end

    it 'does not call log_short_test_name_issue when test name is longer than 3 characters' do
      records = [normal_name_record]

      logging.send(:count_test_codes_and_names, records)

      expect(logging).not_to have_received(:log_short_test_name_issue)
    end

    it 'does not call log_short_test_name_issue when test name is empty' do
      empty_name_record = UnifiedHealthData::LabOrTest.new(
        id: '111',
        type: 'DiagnosticReport',
        display: '',
        test_code: 'CH',
        date_completed: '2023-01-01',
        sample_tested: '',
        encoded_data: '',
        location: '',
        ordered_by: '',
        observations: [],
        body_site: ''
      )

      records = [empty_name_record]

      logging.send(:count_test_codes_and_names, records)

      expect(logging).not_to have_received(:log_short_test_name_issue)
    end

    it 'returns correct counts while logging short name issues' do
      records = [normal_name_record, short_name_record_ch, short_name_record_sp]

      test_code_counts, test_name_counts = logging.send(:count_test_codes_and_names, records)

      expect(test_code_counts).to eq({ 'CH' => 2, 'SP' => 1 })
      expect(test_name_counts).to eq({ 'Chemistry Test' => 1, 'CH' => 1, 'SP' => 1 })
      expect(logging).to have_received(:log_short_test_name_issue).exactly(2).times
    end
  end
end
