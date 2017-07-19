# frozen_string_literal: true
require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits do
  # it_should_behave_like 'saved_claim'
  describe 'validations' do
    subject do
      described_class.new
    end

    it 'should validate form_id' do
      %w(1990 1995 1990e 5490 1990n 5495).each do |form_type|
        subject.form_id = "22-#{form_type.upcase}"
        expect_attr_valid(subject, :form_id)
      end

      subject.form_id = 'foo'
      expect_attr_invalid(subject, :form_id, 'is not included in the list')
    end
  end
end
