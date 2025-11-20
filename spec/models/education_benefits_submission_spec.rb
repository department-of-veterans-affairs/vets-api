# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationBenefitsSubmission, type: :model do
  subject { described_class.new(attributes) }

  let(:attributes) do
    {
      region: 'eastern'
    }
  end

  describe 'validations' do
    it 'validates region is correct' do
      subject.region = 'western'
      expect_attr_valid(subject, :region)

      subject.region = 'canada'
      expect_attr_invalid(subject, :region, 'is not included in the list')
    end

    it 'validates form_type' do
      %w[1995 1990 0993 0994 10203 10297].each do |form_type|
        subject.form_type = form_type
        expect_attr_valid(subject, form_type)
      end

      subject.form_type = 'foo'
      expect_attr_invalid(subject, :form_type, 'is not included in the list')
    end
  end
end
