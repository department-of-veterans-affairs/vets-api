# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA0993 do
  subject { described_class.new(education_benefits_claim) }

  let(:education_benefits_claim) { build(:va0993).education_benefits_claim }

  %w[ssn va_file_number].each do |form|
    test_spool_file('0993', form)
  end

  describe '#direct_deposit_type' do
    let(:education_benefits_claim) { create(:va0993).education_benefits_claim }

    it 'converts internal keys to text' do
      expect(subject.direct_deposit_type('startUpdate')).to eq('Start or Update')
      expect(subject.direct_deposit_type('stop')).to eq('Stop')
      expect(subject.direct_deposit_type('noChange')).to eq('Do Not Change')
    end
  end
end
