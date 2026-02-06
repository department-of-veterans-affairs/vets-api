# frozen_string_literal: true

require 'rails_helper'
require 'feature_flipper'

RSpec.describe BioSubmissionStatusReportJob, type: :aws_helpers do
  subject { described_class.new }

  let(:test_uuid) { 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' }
  let(:cmp_service) { instance_double(CentralMail::Service) }
  let(:cmp_response) do
    double('response', body: [
      { 'uuid' => test_uuid, 'status' => 'Received', 'lastUpdated' => '2025-01-15 12:00:00' }
    ].to_json)
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:bio_submission_status_report_enabled).and_return(true)
    allow(FeatureFlipper).to receive(:send_email?).and_return(true)
    # rubocop:disable RSpec/ReceiveMessages
    allow(CentralMail::Service).to receive(:service_is_up?).and_return(true)
    allow(CentralMail::Service).to receive(:new).and_return(cmp_service)
    # rubocop:enable RSpec/ReceiveMessages
    allow(cmp_service).to receive(:status).and_return(cmp_response)
  end

  describe '#perform' do
    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:bio_submission_status_report_enabled).and_return(false)
      end

      it 'does not generate reports' do
        expect(FormSubmissionAttempt).not_to receive(:joins)
        subject.perform
      end
    end

    context 'when send_email is disabled' do
      before do
        allow(FeatureFlipper).to receive(:send_email?).and_return(false)
      end

      it 'does not generate reports' do
        expect(FormSubmissionAttempt).not_to receive(:joins)
        subject.perform
      end
    end

    context 'with submission data' do
      let!(:form_submission) do
        create(:form_submission, form_type: '21-4192')
      end
      let!(:attempt) do
        create(:form_submission_attempt,
               form_submission:,
               benefits_intake_uuid: test_uuid,
               aasm_state: 'pending',
               lighthouse_updated_at: Time.zone.parse('2025-01-15 10:00:00'))
      end

      it 'generates report and sends email' do
        stub_reports_s3 do
          expect { subject.perform }.to change { ActionMailer::Base.deliveries.count }.by(1)
        end
      end

      it 'generates CSV with correct structure' do
        stub_reports_s3 do
          csv_content = nil
          allow(Reports::Uploader).to receive(:get_s3_link) do |path|
            csv_content = CSV.read(path) if path.include?('21-4192')
            'https://s3.example.com/report.csv'
          end
          subject.perform

          expect(csv_content[0]).to eq(['21-4192 Post-Go-Live Submission Tracker'])

          header_idx = csv_content.index(described_class::HEADER_COLUMNS)
          expect(csv_content.find { |r| r&.first == 'Expected annual submissions' }).to be_present
          expect(csv_content.find { |r| r&.first == 'Total submissions' }).to be_present
          expect(csv_content.find { |r| r&.first == 'Number of Incomplete/Errors' }).to be_present
          expect(header_idx).to be_present

          data_row = csv_content[header_idx + 1]
          expect(data_row[0]).to eq(test_uuid)
          expect(data_row[1]).to eq('pending')
          expect(data_row[3]).to eq('Received')
        end
      end
    end

    context 'when CMP service is down' do
      let(:down_uuid) { 'b2c3d4e5-f6a7-8901-bcde-f12345678901' }
      let!(:form_submission) do
        create(:form_submission, form_type: '21-4192')
      end
      let!(:attempt) do
        create(:form_submission_attempt,
               form_submission:,
               benefits_intake_uuid: down_uuid,
               aasm_state: 'success')
      end

      before do
        allow(CentralMail::Service).to receive(:service_is_up?).and_return(false)
      end

      it 'generates report with blank CMP columns' do
        stub_reports_s3 do
          csv_content = nil
          allow(Reports::Uploader).to receive(:get_s3_link) do |path|
            csv_content = CSV.read(path) if path.include?('21-4192')
            'https://s3.example.com/report.csv'
          end

          subject.perform

          header_idx = csv_content.index(described_class::HEADER_COLUMNS)
          data_row = csv_content[header_idx + 1]
          expect(data_row[0]).to eq(down_uuid)
          expect(data_row[3]).to be_nil
          expect(data_row[4]).to be_nil
        end
      end
    end

    context 'when one form type errors' do
      before do
        create(:form_submission, form_type: '21-4192')
        create(:form_submission, form_type: '21-0779')

        call_count = 0
        allow(FormSubmissionAttempt).to receive(:joins).and_wrap_original do |method, *args|
          result = method.call(*args)
          allow(result).to receive(:where).and_wrap_original do |where_method, *where_args|
            where_result = where_method.call(*where_args)
            call_count += 1
            # Raise error on second where call (first form type, after date filter)
            allow(where_result).to receive(:order).and_raise(StandardError, 'db error') if call_count == 2
            where_result
          end
          result
        end
      end

      it 'continues processing other form types' do
        stub_reports_s3 do
          expect(Rails.logger).to receive(:error).with(/Error generating report/)
          expect { subject.perform }.to change { ActionMailer::Base.deliveries.count }.by(1)
        end
      end
    end

    context 'when CMP status call raises an error' do
      let(:error_uuid) { 'c3d4e5f6-a7b8-9012-cdef-123456789012' }
      let!(:form_submission) do
        create(:form_submission, form_type: '21-4192')
      end
      let!(:attempt) do
        create(:form_submission_attempt, form_submission:, benefits_intake_uuid: error_uuid)
      end

      before do
        allow(cmp_service).to receive(:status).and_raise(StandardError, 'CMP timeout')
      end

      it 'generates report with blank CMP columns' do
        stub_reports_s3 do
          csv_content = nil
          allow(Reports::Uploader).to receive(:get_s3_link) do |path|
            csv_content = CSV.read(path) if path.include?('21-4192')
            'https://s3.example.com/report.csv'
          end

          expect(Rails.logger).to receive(:warn).with(/CMP status fetch failed/)
          subject.perform

          header_idx = csv_content.index(described_class::HEADER_COLUMNS)
          data_row = csv_content[header_idx + 1]
          expect(data_row[3]).to be_nil
          expect(data_row[4]).to be_nil
        end
      end
    end
  end
end
