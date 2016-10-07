require 'rails_helper'

RSpec.describe EducationForm::CreateDailyYearToDateReport do
  subject { described_class.new }
  let(:date) { Date.today }

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

      create(
        :education_benefits_claim_with_custom_form,
        custom_form: {
          'school' => {
            'address' => {
              'state' => 'CA'
            }
          }
        }
      )

      create(:education_benefits_claim).tap do |education_benefits_claim|
        education_benefits_claim.update_column(:submitted_at, date - 1.year)
      end
    end

    describe '#create_csv_array' do
      it 'should make the right csv array' do
        expect(subject.create_csv_array(date)).to eq(
          [
            ["Submitted Vets.gov Applications - Report FYTD #{date.year} as of #{date}"],
            ["", "", "DOCUMENT TYPE"],
            ["RPO", "BENEFIT TYPE", "22-1990"],
            ["BUFFALO (307)", "chapter33", 2],
            ["", "chapter30", 0],
            ["", "chapter1606", 0],
            ["", "chapter32", 0],
            ["", "TOTAL", 2],
            ["ATLANTA (316)", "chapter33", 0],
            ["", "chapter30", 0],
            ["", "chapter1606", 0],
            ["", "chapter32", 0],
            ["", "TOTAL", 0],
            ["ST. LOUIS (331)", "chapter33", 0],
            ["", "chapter30", 0],
            ["", "chapter1606", 0],
            ["", "chapter32", 0],
            ["", "TOTAL", 0],
            ["MUSKOGEE (351)", "chapter33", 0],
            ["", "chapter30", 0],
            ["", "chapter1606", 1],
            ["", "chapter32", 0],
            ["", "TOTAL", 1],
            ["ALL RPOS TOTAL", "", 3],
            ["", "", "22-1990"]
          ]
        )
      end
    end

    describe '#get_submissions' do
      it 'should calculate number of submissions correctly' do
        expect(subject.get_submissions(date)).to eq(
          {
            :eastern=>{"chapter33"=>2, "chapter30"=>0, "chapter1606"=>0, "chapter32"=>0},
            :southern=>{"chapter33"=>0, "chapter30"=>0, "chapter1606"=>0, "chapter32"=>0},
            :central=>{"chapter33"=>0, "chapter30"=>0, "chapter1606"=>0, "chapter32"=>0},
            :western=>{"chapter33"=>0, "chapter30"=>0, "chapter1606"=>1, "chapter32"=>0}
          }
        )
      end
    end
  end

  it 'should create the year to date report' do
    # subject.perform
  end
end
