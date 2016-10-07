require 'rails_helper'

RSpec.describe EducationForm::CreateDailyYearToDateReport do
  subject { described_class.new }

  describe '#get_submissions' do
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
    end

    it 'should calculate number of submissions correctly' do
      expect(subject.get_submissions).to eq(
        {
          :eastern=>{"chapter33"=>2, "chapter30"=>0, "chapter1606"=>0, "chapter32"=>0},
          :southern=>{"chapter33"=>0, "chapter30"=>0, "chapter1606"=>0, "chapter32"=>0},
          :central=>{"chapter33"=>0, "chapter30"=>0, "chapter1606"=>0, "chapter32"=>0},
          :western=>{"chapter33"=>0, "chapter30"=>0, "chapter1606"=>1, "chapter32"=>0}
        }
      )
    end
  end

  it 'should create the year to date report' do
    subject.perform
  end
end
