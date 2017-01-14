# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1995 do
  let(:education_benefits_claim) { create(:education_benefits_claim_1995) }

  subject { described_class.new(education_benefits_claim) }

  it 'has a 22-1995 type' do
    expect(described_class::TYPE).to eq('22-1995')
  end

  describe '#text' do
    it 'should generate the spool file correctly' do
      
    end
  end
end
