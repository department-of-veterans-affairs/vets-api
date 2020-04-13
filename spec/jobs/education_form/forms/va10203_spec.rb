# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10203 do
  subject { described_class.new(education_benefits_claim) }

  context '#direct_deposit_type' do
    let(:education_benefits_claim) { create(:va10203_full_form).education_benefits_claim }

    it 'converts internal keys to text' do
      expect(subject.school['name']).to eq('Test School Name')
      expect(subject.header_form_type).to eq('V10203')
    end
  end
end
