# frozen_string_literal: true
require 'rails_helper'

def get_education_form_fixture(filename)
  get_fixture("education_form/#{filename}")
end

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
      %w(1995 1990e 5490 1990n 5495).each do |form_type|
        create(:education_benefits_submission, form_type: form_type, created_at: date)
      end
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
            get_education_form_fixture('create_csv_array')
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
                get_education_form_fixture("ytd_#{range_type}_#{status}")
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
