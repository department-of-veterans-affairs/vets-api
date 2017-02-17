# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1995 do
  let(:education_benefits_claim) { build(:education_benefits_claim_1995) }

  subject { described_class.new(education_benefits_claim) }

  it 'has a 22-1995 type' do
    expect(described_class::TYPE).to eq('22-1995')
  end

  test_spool_file('1995', 'kitchen_sink')
end
