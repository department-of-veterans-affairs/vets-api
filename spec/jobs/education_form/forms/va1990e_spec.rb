# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1990e do
  let(:education_benefits_claim) { build(:education_benefits_claim_1990e) }

  subject { described_class.new(education_benefits_claim) }

  context 'method tests' do
    before do
      allow_any_instance_of(described_class).to receive(:format)
    end

    describe '#benefit_type' do
      it 'should return the benefit type shorthand' do
        expect(subject.benefit_type(education_benefits_claim.open_struct_form)).to eq('CH1606')
      end
    end
  end

  %w(kitchen_sink simple).each do |test_application|
    test_spool_file('1990e', test_application)
  end
end
