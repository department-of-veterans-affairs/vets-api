# frozen_string_literal: true

require 'rails_helper'

def get_education_form_fixture(filename)
  get_fixture("education_form/#{filename}")
end

RSpec.describe EducationForm::CreateDailyFiscalYearToDateReport, type: :aws_helpers do
  subject do
    described_class.new
  end

  let(:date) { Time.zone.today - 1.day }

  before do
    allow_any_instance_of(EducationBenefitsClaim).to receive(:create_education_benefits_submission)
  end

  context 'with a report date of 2017-09-30' do
    subject do
      described_class.new('2017-09-30'.to_date)
    end

    describe '#fiscal_year' do
      it 'returns a fiscal year of 2017' do
        expect(subject.fiscal_year).to eq(2017)
      end
    end

    describe '#beginning_of_fiscal_year' do
      it 'returns a October 1st, 2016' do
        expect(subject.beginning_of_fiscal_year).to eq(Date.new(2016, 10))
      end
    end
  end

  context 'with a report date of 2017-10-01' do
    subject do
      described_class.new('2017-10-01'.to_date)
    end

    describe '#fiscal_year' do
      it 'returns a fiscal year of 2018' do
        expect(subject.fiscal_year).to eq(2018)
      end
    end

    describe '#beginning_of_fiscal_year' do
      it 'returns a October 1st, 2017' do
        expect(subject.beginning_of_fiscal_year).to eq(Date.new(2017, 10))
      end
    end
  end

  context 'with some sample submissions', run_at: '2017-01-10 03:00:00 EDT' do
    before do
      create_list(:education_benefits_submission, 2, status: :processed, created_at: date)

      create(
        :education_benefits_submission,
        status: :processed,
        region: :western,
        chapter33: false,
        chapter1606: true,
        created_at: date
      )

      # outside of yearly range
      create(:education_benefits_submission, created_at: date - 2.years, status: 'processed')
      # outside of daily range, given the timecop freeze.
      create(:education_benefits_submission, created_at: date - 26.hours, status: 'processed')

      create(:education_benefits_submission, created_at: date, status: 'submitted')
      %w[1995 1990e 5490 1990n 5495 10203].each do |form_type|
        create(:education_benefits_submission, form_type:, created_at: date)
      end
      create(:education_benefits_submission, form_type: '0993', created_at: date, region: :western)
      create(:education_benefits_submission, form_type: '0994',
                                             created_at: date, region: :eastern, vettec: true, chapter33: false)
      create(:education_benefits_submission, form_type: '1990s',
                                             created_at: date, region: :western, vrrap: true, chapter33: false)
    end

    context 'with the date variable set' do
      subject do
        job_with_date
      end

      let(:job_with_date) do
        job = described_class.new(date)
        job
      end

      describe '#create_csv_array' do
        it 'makes the right csv array' do
          expect(subject.create_csv_array).to eq(
            get_education_form_fixture('fiscal_year_create_csv_array')
          )
        end
      end

      describe '#calculate_submissions' do
        subject do
          job_with_date.create_csv_header
          job_with_date.calculate_submissions(range_type:, status:)
        end

        def self.verify_status_numbers(status, result)
          context "for #{status} applications" do
            let(:status) { status }

            it 'returns data about the number of submissions' do
              expect(subject.deep_stringify_keys).to eq(result)
            end
          end
        end

        %i[day year].each do |range_type|
          %i[processed submitted].each do |status|
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
      subject do
        create_daily_year_to_date_report = described_class.new

        stub_reports_s3(filename) do
          create_daily_year_to_date_report.perform
        end

        create_daily_year_to_date_report
      end

      before do
        expect(FeatureFlipper).to receive(:send_edu_report_email?).once.and_return(true)
      end

      after do
        File.delete(filename)
      end

      let(:filename) { "tmp/daily_reports/#{date}.csv" }

      it 'creates a csv file' do
        subject

        csv_string = CSV.generate do |csv|
          subject.create_csv_array.each do |row|
            csv << row
          end
        end

        expect(File.read(filename)).to eq(csv_string)
      end

      it 'sends an email' do
        expect { subject }.to change {
          ActionMailer::Base.deliveries.count
        }.by(1)
      end
    end
  end
end
