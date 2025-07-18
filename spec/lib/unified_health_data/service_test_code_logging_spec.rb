# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'
require 'unified_health_data/models/lab_or_test'

RSpec.describe UnifiedHealthData::Service do
  describe '#log_test_code_distribution' do
    let(:user) { build(:user, :loa3) }
    let(:service) { described_class.new(user) }
    let(:ch_record) do
      UnifiedHealthData::LabOrTest.new(
        id: '123',
        type: 'DiagnosticReport',
        attributes: UnifiedHealthData::Attributes.new(
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
      )
    end
    let(:sp_record) do
      UnifiedHealthData::LabOrTest.new(
        id: '456',
        type: 'DiagnosticReport',
        attributes: UnifiedHealthData::Attributes.new(
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
      )
    end
    let(:cy_record) do
      UnifiedHealthData::LabOrTest.new(
        id: '789',
        type: 'DiagnosticReport',
        attributes: UnifiedHealthData::Attributes.new(
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
      )
    end
    let(:mb_record) do
      UnifiedHealthData::LabOrTest.new(
        id: '999',
        type: 'DiagnosticReport',
        attributes: UnifiedHealthData::Attributes.new(
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
      )
    end

    before do
      allow(service).to receive(:with_monitoring).and_yield
      allow(Rails.logger).to receive(:info)
    end

    it 'logs test code distribution with counts' do
      # Create a sample set of records with multiple test codes
      records = [ch_record, sp_record, ch_record, cy_record, mb_record, ch_record]

      # Call the private method directly using send
      service.send(:log_test_code_distribution, records)

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
      service.send(:log_test_code_distribution, [])
      expect(Rails.logger).not_to have_received(:info)
    end

    it 'handles records with missing test codes' do
      record_with_no_code = UnifiedHealthData::LabOrTest.new(
        id: '123',
        type: 'DiagnosticReport',
        attributes: UnifiedHealthData::Attributes.new(
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
      )

      records = [ch_record, record_with_no_code, sp_record]
      service.send(:log_test_code_distribution, records)

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
        attributes: UnifiedHealthData::Attributes.new(
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
      )

      records = [ch_record, record_with_no_name, sp_record]
      service.send(:log_test_code_distribution, records)

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
        attributes: UnifiedHealthData::Attributes.new(
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
      )

      records = [record_with_special_chars, sp_record]
      service.send(:log_test_code_distribution, records)

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
end
