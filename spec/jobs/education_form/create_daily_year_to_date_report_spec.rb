# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::CreateDailyYearToDateReport do
  let(:date) { Time.zone.today }
  subject do
    described_class.new
  end

  context 'with some sample submissions' do
    before do
      2.times do
        create(
          :education_benefits_claim_with_custom_form,
          custom_form: {
            'chapter1606' => false,
            'chapter33' => true
          }
        )
      end

      create(:education_benefits_claim_western_region)

      EducationBenefitsClaim.delete_all

      create(:education_benefits_submission, created_at: date - 1.year)
    end

    context 'with the date variable set' do
      subject do
        job = described_class.new
        job.instance_variable_set(:@date, date)
        job
      end

      describe '#create_csv_array' do
        it 'should make the right csv array' do
          expect(subject.create_csv_array).to eq(
            [
              ["Submitted Vets.gov Applications - Report FYTD #{date.year} as of #{date}"],
              ['', '', 'DOCUMENT TYPE'],
              ['RPO', 'BENEFIT TYPE', '22-1990'],
              ['BUFFALO (307)', 'chapter33', 2],
              ['', 'chapter30', 0],
              ['', 'chapter1606', 0],
              ['', 'chapter32', 0],
              ['', 'TOTAL', 2],
              ['ATLANTA (316)', 'chapter33', 0],
              ['', 'chapter30', 0],
              ['', 'chapter1606', 0],
              ['', 'chapter32', 0],
              ['', 'TOTAL', 0],
              ['ST. LOUIS (331)', 'chapter33', 0],
              ['', 'chapter30', 0],
              ['', 'chapter1606', 0],
              ['', 'chapter32', 0],
              ['', 'TOTAL', 0],
              ['MUSKOGEE (351)', 'chapter33', 0],
              ['', 'chapter30', 0],
              ['', 'chapter1606', 1],
              ['', 'chapter32', 0],
              ['', 'TOTAL', 1],
              ['ALL RPOS TOTAL', '', 3],
              ['', '', '22-1990']
            ]
          )
        end
      end

      describe '#calculate_submissions' do
        it 'should return data about the number of submissions' do
          expect(subject.calculate_submissions).to eq(
            eastern: { 'chapter33' => 2, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            southern: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            central: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 0, 'chapter32' => 0 },
            western: { 'chapter33' => 0, 'chapter30' => 0, 'chapter1606' => 1, 'chapter32' => 0 }
          )
        end
      end
    end

    describe '#perform' do
      it 'should create a csv file' do
        subject.perform(date)

        csv_string = CSV.generate do |csv|
          subject.create_csv_array.each do |row|
            csv << row
          end
        end

        expect(File.read("tmp/daily_reports/#{date}.csv")).to eq(csv_string)
      end
    end
  end
end
