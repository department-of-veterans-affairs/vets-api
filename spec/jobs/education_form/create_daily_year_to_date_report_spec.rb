# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::CreateDailyYearToDateReport, type: :aws_helpers do
  let(:date) { Time.zone.today }
  subject do
    described_class.new
  end

  context 'with some sample submissions', run_at: '2017-01-03 03:00:00 EDT' do
    before do
      2.times do
        create(
          :education_benefits_claim_with_custom_form,
          processed_at: date,
          custom_form: {
            'privacyAgreementAccepted' => true,
            'chapter1606' => false,
            'chapter33' => true
          }
        )
      end

      create(:education_benefits_claim_western_region, processed_at: date)

      EducationBenefitsClaim.delete_all

      # outside of yearly range
      create(:education_benefits_submission, created_at: date - 1.year, status: 'processed')
      # outside of daily range, given the timecop freeze.
      create(:education_benefits_submission, created_at: date - 26.hours, status: 'processed')

      create(:education_benefits_submission, created_at: date, status: 'submitted')
    end

    context 'with the date variable set' do
      let(:job_with_date) do
        job = described_class.new
        job.instance_variable_set(:@date, date)
        job
      end

      subject do
        job_with_date
      end

      describe '#create_csv_array' do
        it 'should make the right csv array' do
          year_range = (date.beginning_of_year..date.end_of_day).to_s
          day_range = (date.beginning_of_day..date.end_of_day).to_s

          expect(subject.create_csv_array).to eq(
            [
              ["Submitted Vets.gov Applications - Report FYTD #{date.year} as of #{date}"],
              ['', '', 'DOCUMENT TYPE'],
              ['RPO', 'BENEFIT TYPE', '22-1990'],
              ['', '', year_range, '', day_range],
              ['', '', '', 'Submitted', 'Uploaded to TIMS'],
              ['BUFFALO (307)', 'chapter33', 3, 3, 2],
              ['', 'chapter30', 0, 0, 0],
              ['', 'chapter1606', 0, 0, 0],
              ['', 'chapter32', 0, 0, 0],
              ['', 'TOTAL', 3, 3, 2],
              ['ATLANTA (316)', 'chapter33', 0, 0, 0],
              ['', 'chapter30', 0, 0, 0],
              ['', 'chapter1606', 0, 0, 0],
              ['', 'chapter32', 0, 0, 0],
              ['', 'TOTAL', 0, 0, 0],
              ['ST. LOUIS (331)', 'chapter33', 0, 0, 0],
              ['', 'chapter30', 0, 0, 0],
              ['', 'chapter1606', 0, 0, 0],
              ['', 'chapter32', 0, 0, 0],
              ['', 'TOTAL', 0, 0, 0],
              ['MUSKOGEE (351)', 'chapter33', 0, 0, 0],
              ['', 'chapter30', 0, 0, 0],
              ['', 'chapter1606', 1, 1, 1],
              ['', 'chapter32', 0, 0, 0],
              ['', 'TOTAL', 1, 1, 1],
              ['ALL RPOS TOTAL', '', 4, 4, 3],
              ['', '', '22-1990']
            ]
          )
        end
      end

      describe '#calculate_submissions' do
        subject do
          job_with_date.create_csv_header
          job_with_date.calculate_submissions(range_type: range_type, status: status)
        end

        def self.verify_status_numbers(status, result)
          context "for #{status} applications" do
            let(:status) { status }

            it 'should return data about the number of submissions' do
              expect(subject).to eq(result)
            end
          end
        end

        context 'for the current year' do
          let(:range_type) { :year }

          verify_status_numbers(
            :processed,
            eastern: { 'chapter33' => 3, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            southern: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            central: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            western: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 1, 'chapter32' => 0 }
          )

          verify_status_numbers(
            :submitted,
            eastern: { 'chapter33' => 4, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            southern: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            central: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            western: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 1, 'chapter32' => 0 }
          )
        end

        context 'for the current day' do
          let(:range_type) { :day }

          verify_status_numbers(
            :processed,
            eastern: { 'chapter33' => 2, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            southern: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            central: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            western: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 1, 'chapter32' => 0 }
          )

          verify_status_numbers(
            :submitted,
            eastern: { 'chapter33' => 3, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            southern: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            central: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            western: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 1, 'chapter32' => 0 }
          )
        end
      end
    end

    describe '#perform' do
      let(:filename) { "tmp/daily_reports/#{date - 1.day}.csv" }
      subject do
        create_daily_year_to_date_report = described_class.new

        stub_reports_s3(filename) do
          create_daily_year_to_date_report.perform
        end

        create_daily_year_to_date_report
      end

      it 'should create a csv file' do
        subject

        csv_string = CSV.generate do |csv|
          subject.create_csv_array.each do |row|
            csv << row
          end
        end

        expect(File.read(filename)).to eq(csv_string)
      end

      it 'should send an email' do
        expect { subject }.to change {
          ActionMailer::Base.deliveries.count
        }.by(1)
      end
    end
  end
end
