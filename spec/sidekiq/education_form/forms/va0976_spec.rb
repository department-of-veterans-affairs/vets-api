# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA0976 do
  subject { described_class.new(application) }

  before do
    allow_any_instance_of(EducationForm::Forms::Base).to receive(:format).and_return('')
  end

  let(:application) { create(:va8794).education_benefits_claim }

  it 'exposes the header form type' do
    expect(subject.header_form_type).to eq('V0976')
  end
end
