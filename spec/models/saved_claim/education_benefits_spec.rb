# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::EducationBenefits do
  describe '.form_class' do
    it 'raises an error if the form_type is invalid' do
      expect { described_class.form_class('foo') }.to raise_error('Invalid form type')
    end

    it 'returns the form class for a form type' do
      expect(described_class.form_class('1990')).to eq(SavedClaim::EducationBenefits::VA1990)
    end
  end

  describe '#in_progress_form_id' do
    it 'returns form_id' do
      form = create(:va1990)
      expect(form.in_progress_form_id).to eq(form.form_id)
    end
  end
end
