# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::CreateDailyYearToDateReport, type: :aws_helpers do
  let(:date) { Time.zone.today - 1.day }
  subject do
    described_class.new
  end

  context 'with some sample submissions', run_at: '2017-01-04 03:00:00 EDT' do
    before do
      2.times do
        create(:education_benefits_submission, status: :processed, created_at: date)
      end

      create(
        :education_benefits_submission,
        status: :processed,
        region: :western,
        chapter33: false,
        chapter1606: true,
        created_at: date
      )

      # outside of yearly range
      create(:education_benefits_submission, created_at: date - 1.year, status: 'processed')
      # outside of daily range, given the timecop freeze.
      create(:education_benefits_submission, created_at: date - 26.hours, status: 'processed')

      create(:education_benefits_submission, created_at: date, status: 'submitted')
      create(:education_benefits_submission, form_type: '1995', created_at: date)
      create(:education_benefits_submission, form_type: '1990e', created_at: date)
      create(:education_benefits_submission, form_type: '5490', created_at: date)
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
          expect(subject.create_csv_array).to eq(
            [['Submitted Vets.gov Applications - Report FYTD 2017 as of 2017-01-03'],
             ['', '', 'DOCUMENT TYPE'],
             ['RPO', 'BENEFIT TYPE', '22-1990', '', '', '22-1995', '', '', '22-1990e', '', '', '22-5490', '', ''],
             ['',
              '',
              '2017-01-01..2017-01-03 23:59:59 UTC',
              '',
              '2017-01-03 00:00:00 UTC..2017-01-03 23:59:59 UTC',
              '2017-01-01..2017-01-03 23:59:59 UTC',
              '',
              '2017-01-03 00:00:00 UTC..2017-01-03 23:59:59 UTC',
              '2017-01-01..2017-01-03 23:59:59 UTC',
              '',
              '2017-01-03 00:00:00 UTC..2017-01-03 23:59:59 UTC',
              '2017-01-01..2017-01-03 23:59:59 UTC',
              '',
              '2017-01-03 00:00:00 UTC..2017-01-03 23:59:59 UTC'],
             ['',
              '',
              '',
              'Submitted',
              'Sent to Spool File',
              '',
              'Submitted',
              'Sent to Spool File',
              '',
              'Submitted',
              'Sent to Spool File',
              '',
              'Submitted',
              'Sent to Spool File'],
             ['BUFFALO (307)', 'chapter33', 3, 3, 2, '', '', '', 0, 1, 0, 0, 1, 0],
             ['', 'chapter30', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter1606', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter32', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter35', 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
             ['', 'TOTAL', 3, 3, 2, 0, 1, 0, 0, 1, 0, 0, 1, 0],
             ['ATLANTA (316)', 'chapter33', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter30', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter1606', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter32', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter35', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
             ['', 'TOTAL', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
             ['ST. LOUIS (331)', 'chapter33', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter30', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter1606', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter32', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter35', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
             ['', 'TOTAL', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
             ['MUSKOGEE (351)', 'chapter33', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter30', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter1606', 1, 1, 1, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter32', 0, 0, 0, '', '', '', 0, 0, 0, 0, 0, 0],
             ['', 'chapter35', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
             ['', 'TOTAL', 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
             ['ALL RPOS TOTAL', '', 4, 4, 3, 0, 1, 0, 0, 1, 0, 0, 1, 0],
             ['', '', '22-1990', '', '', '22-1995', '', '', '22-1990e', '', '', '22-5490', '', '']]
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
              expect(subject.deep_stringify_keys).to eq(result)
            end
          end
        end

        %i(day year).each do |range_type|
          %i(processed submitted).each do |status|
            context "for the current #{range_type}" do
              let(:range_type) { range_type }

              verify_status_numbers(
                status,
                JSON.parse(File.read("spec/fixtures/education_form/ytd_#{range_type}_#{status}.json"))
              )
            end
          end
        end
      end
    end

    describe '#perform' do
      let(:filename) { "tmp/daily_reports/#{date}.csv" }
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
