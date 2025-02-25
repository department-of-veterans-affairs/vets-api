# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::ReportMonthlySubmissions, type: :job do
  describe '#perform' do
    context 'when the monthly report setting is disabled' do
      before { allow(VBADocuments::MonthlyReportMailer).to receive(:build) }

      it 'does not build the monthly report' do
        with_settings(Settings.vba_documents, monthly_report: false) do
          expect(VBADocuments::MonthlyReportMailer).not_to receive(:build)

          described_class.new.perform
        end
      end
    end

    context 'when the monthly report setting is enabled' do
      let(:monthly_stats_generator) { instance_double(VBADocuments::MonthlyStatsGenerator) }
      let(:prior_twelve_months_stats) { [] }

      before do
        12.times do |i|
          reporting_date = (i + 1).months.ago
          prior_twelve_months_stats <<
            create(:monthly_stat, month: reporting_date.month, year: reporting_date.year)
        end

        allow(VBADocuments::MonthlyStatsGenerator).to receive(:new).and_return(monthly_stats_generator)
        allow(monthly_stats_generator).to receive(:generate_and_save_stats)
        allow(VBADocuments::MonthlyReportMailer).to receive(:build).and_return(
          double.tap do |mailer|
            allow(mailer).to receive(:deliver_now).once
          end
        )
      end

      it 'generates the prior month stats' do
        with_settings(Settings.vba_documents, monthly_report: true) do
          expect(VBADocuments::MonthlyStatsGenerator).to receive(:new).with(
            month: 1.month.ago.month, year: 1.month.ago.year
          ).and_return(monthly_stats_generator)
          expect(monthly_stats_generator).to receive(:generate_and_save_stats)

          described_class.new.perform
        end
      end

      it 'calls the monthly report mailer with the prior 12 month stats to send the email' do
        with_settings(Settings.vba_documents, monthly_report: true) do
          expect(VBADocuments::MonthlyReportMailer).to receive(:build).with(
            prior_twelve_months_stats
          ).and_return(
            double.tap do |mailer|
              expect(mailer).to receive(:deliver_now).once
            end
          )

          described_class.new.perform
        end
      end
    end
  end
end
