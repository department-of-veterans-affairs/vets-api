require 'rails_helper'

RSpec.describe EducationForm::CreateDailyYearToDateReport do
  subject { described_class.new }

  describe '#get_submissions' do
    before do
      build(:education_benefits_claim)
    end

    it 'should calcuate number of submissions correctly' do
    end
  end

  it 'should create the year to date report' do
    subject.perform
  end
end
