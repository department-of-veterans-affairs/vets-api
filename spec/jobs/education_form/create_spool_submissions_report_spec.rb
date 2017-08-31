# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::CreateSpoolSubmissionsReport, type: :aws_helpers do
  let(:date) { Time.zone.today - 1.day }
  subject do
    described_class.new
  end

  context 'with some sample claims', run_at: '2017-07-27 00:00:00 -0400' do
    let!(:education_benefits_claim_1) do
      create(:education_benefits_claim_1990e, processed_at: date)
    end

    let!(:education_benefits_claim_2) do
      create(:education_benefits_claim_1990n, processed_at: date)
    end

    before do
      subject.instance_variable_set(:@date, date)
    end

    describe '#create_csv_array' do
      it 'should create the right array' do
        expect(
          subject.create_csv_array
        ).to eq(
          [['Claimant Name', 'Veteran Name', 'Confirmation #', 'Time Submitted', 'RPO'],
           ['Mark Olson', nil, education_benefits_claim_1.confirmation_number, '2017-07-26 00:00:00 UTC', 'eastern'],
           [nil, 'Mark Olson', education_benefits_claim_2.confirmation_number, '2017-07-26 00:00:00 UTC', 'eastern']]
        )
      end

      describe '#perform' do
        after do
          File.delete(filename)
        end

        let(:filename) { "tmp/spool_reports/#{date}.csv" }

        def perform
          stub_reports_s3(filename) do
            subject.perform
          end
        end

        it 'should create a csv file' do
          perform

          csv_string = CSV.generate do |csv|
            subject.create_csv_array.each do |row|
              csv << row
            end
          end

          expect(File.read(filename)).to eq(csv_string)
        end

        it 'should send an email' do
          expect { perform }.to change {
            ActionMailer::Base.deliveries.count
          }.by(1)
        end
      end
    end
  end
end
