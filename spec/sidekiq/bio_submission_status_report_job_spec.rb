# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BioSubmissionStatusReportJob, type: :aws_helpers do
  subject { described_class.new }

  let(:cmp_service) { instance_double(CentralMail::Service) }
  let(:cmp_response) do
    double('response', body: [
      { 'uuid' => 'uuid-1', 'status' => 'Received', 'lastUpdated' => '2025-01-15 12:00:00' }
    ].to_json)
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:bio_submission_status_report_enabled).and_return(true)
    allow(FeatureFlipper).to receive_messages(send_email?: true)
    allow(CentralMail::Service).to receive_messages(service_is_up?: true, new: cmp_service)
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
               benefits_intake_uuid: 'uuid-1',
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
          expect(csv_content[2][0]).to eq('Expected annual submissions')
          expect(csv_content[3][0]).to eq('Total submissions')
          expect(csv_content[4][0]).to eq('Number of Incomplete/Errors')
          expect(csv_content[6]).to eq(described_class::HEADER_COLUMNS)
          expect(csv_content[7][0]).to eq('uuid-1')
          expect(csv_content[7][1]).to eq('pending')
          expect(csv_content[7][3]).to eq('Received')
        end
      end
    end

    context 'when CMP service is down' do
      let!(:form_submission) do
        create(:form_submission, form_type: '21-4192')
      end
      let!(:attempt) do
        create(:form_submission_attempt,
               form_submission:,
               benefits_intake_uuid: 'uuid-2',
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

          data_row = csv_content[7]
          expect(data_row[0]).to eq('uuid-2')
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
            if call_count == 1
              allow(where_result).to receive(:order).and_raise(StandardError, 'db error')
            end
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
      let!(:form_submission) do
        create(:form_submission, form_type: '21-4192')
      end
      let!(:attempt) do
        create(:form_submission_attempt, form_submission:, benefits_intake_uuid: 'uuid-3')
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

          data_row = csv_content[7]
          expect(data_row[3]).to be_nil
          expect(data_row[4]).to be_nil
        end
      end
    end
  end
end
