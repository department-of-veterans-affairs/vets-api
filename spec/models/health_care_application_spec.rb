# frozen_string_literal: true
require 'rails_helper'

RSpec.describe HealthCareApplication, type: :model do
  describe 'validations' do
    it 'should validate presence of state' do
      health_care_application = described_class.new(state: nil)
      expect_attr_invalid(health_care_application, :state, "can't be blank")
    end

    it 'should validate inclusion of state' do
      health_care_application = described_class.new

      %w(success error failed pending).each do |state|
        health_care_application.state = state
        expect_attr_valid(health_care_application, :state)
      end

      health_care_application.state = 'foo'
      expect_attr_invalid(health_care_application, :state, 'is not included in the list')
    end

    it 'should validate presence of form_submission_id and timestamp if success' do
      health_care_application = described_class.new

      %w(form_submission_id timestamp).each do |attr|
        health_care_application.state = 'success'
        expect_attr_invalid(health_care_application, attr, "can't be blank")

        health_care_application.state = 'pending'
        expect_attr_valid(health_care_application, attr)
      end
    end
  end
end
