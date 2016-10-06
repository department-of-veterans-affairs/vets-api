require 'rails_helper'

RSpec.describe EducationForm::CreateDailyYearToDateReport do
  subject { described_class.new }

  it 'should create the year to date report' do
    subject.perform
  end
end
