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

      %w[success error failed pending].each do |state|
        health_care_application.state = state
        expect_attr_valid(health_care_application, :state)
      end

      health_care_application.state = 'foo'
      expect_attr_invalid(health_care_application, :state, 'is not included in the list')
    end

    it 'should validate presence of form_submission_id and timestamp if success' do
      health_care_application = described_class.new

      %w[form_submission_id_string timestamp].each do |attr|
        health_care_application.state = 'success'
        expect_attr_invalid(health_care_application, attr, "can't be blank")

        health_care_application.state = 'pending'
        expect_attr_valid(health_care_application, attr)
      end
    end
  end

  describe '#process!' do
    context 'with an invalid record' do
      it 'should raise a validation error' do
        expect do
          described_class.new(form: {}.to_json).process!
        end.to raise_error(Common::Exceptions::ValidationErrors)
      end
    end

    context 'with an email' do
      context 'with async compatible flag set' do
        it 'should save the record and submit async' do
          health_care_application = build(:health_care_application)
          health_care_application.async_compatible = true
          expect(HCA::SubmissionJob).to receive(:perform_async)

          expect(health_care_application.process!).to eq(health_care_application)
          expect(health_care_application.id.present?).to eq(true)
        end
      end
    end
  end

  describe '#set_result_on_success!' do
    let(:result) do
      {
        formSubmissionId: 123,
        timestamp: '2017-08-03 22:02:18 -0400'
      }
    end

    it 'should set the right fields and save the application' do
      health_care_application = build(:health_care_application)
      health_care_application.set_result_on_success!(result)

      expect(health_care_application.id.present?).to eq(true)
      expect(health_care_application.success?).to eq(true)
      expect(health_care_application.form_submission_id).to eq(result[:formSubmissionId])
      expect(health_care_application.timestamp).to eq(result[:timestamp])
    end
  end
end
