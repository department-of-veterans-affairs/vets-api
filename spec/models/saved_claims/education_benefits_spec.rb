# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::EducationBenefits do
  describe '.form_class' do
    it 'should raise an error if the form_type is invalid' do
      expect { described_class.form_class('foo') }.to raise_error('Invalid form type')
    end

    it 'should return the form class for a form type' do
      expect(described_class.form_class('1990')).to eq(SavedClaim::EducationBenefits::VA1990)
    end
  end
end
