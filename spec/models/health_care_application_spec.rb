# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthCareApplication, type: :model do
  describe 'validations' do
    it 'should validate presence of state' do
      health_care_application = described_class.new(state: nil)
      expect_attr_invalid(health_care_application, :state, "can't be blank")
    end

    describe '#discharge_type_correct', run_at: '2017-01-04 03:00:00 EDT' do
      def self.form_should_be_valid
        it 'should be valid' do
          expect_attr_valid(health_care_application, :form)
        end
      end

      let(:health_care_application) { build(:health_care_application) }
      let(:discharge_type) { nil }

      before do
        form = health_care_application.parsed_form
        form['lastDischargeDate'] = discharge_date
        form['dischargeType'] = discharge_type

        health_care_application.form = form.compact.to_json
        health_care_application.instance_variable_set(:@parsed_form, nil)
      end

      context 'with no discharge date' do
        let(:discharge_date) { nil }

        it 'should not validate discharge type' do
          health_care_application.send(:discharge_type_correct)
          expect(health_care_application.errors.blank?).to eq(true)
        end
      end

      context 'with a future discharge date' do
        let(:discharge_date) { Time.zone.today + 1.day }

        context 'with a discharge type' do
          let(:discharge_type) { 'general' }

          it 'should create a validation error' do
            expect_attr_invalid(
              health_care_application,
              :form,
              'dischargeType must be blank if the discharge date is in the future'
            )
          end
        end

        context 'without a discharge type' do
          form_should_be_valid
        end
      end

      context 'with a non-future discharge date' do
        let(:discharge_date) { Time.zone.today }

        context 'with a discharge type' do
          let(:discharge_type) { 'general' }

          form_should_be_valid
        end

        context 'without a discharge type' do
          it 'should create a validation error' do
            expect_attr_invalid(
              health_care_application,
              :form,
              'dischargeType must be selected if discharge date is not in the future'
            )
          end
        end
      end
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
    let(:health_care_application) { build(:health_care_application) }

    context 'with an invalid record' do
      it 'should raise a validation error' do
        expect do
          described_class.new(form: {}.to_json).process!
        end.to raise_error(Common::Exceptions::ValidationErrors)
      end
    end

    context 'with no email' do
      before do
        new_form = JSON.parse(health_care_application.form)
        new_form.delete('email')
        health_care_application.form = new_form.to_json
        health_care_application.instance_variable_set(:@parsed_form, nil)
      end

      it 'should sumbit sync' do
        result = { formSubmissionId: '123' }
        expect_any_instance_of(HCA::Service).to receive(
          :submit_form
        ).with(health_care_application.send(:parsed_form)).and_return(
          result
        )
        expect(health_care_application.process!).to eq(result)
      end
    end

    context 'with an email' do
      context 'with async_compatible not set' do
        it 'should submit sync', run_at: '2017-01-31' do
          VCR.use_cassette('hca/submit_anon', match_requests_on: [:body]) do
            result = health_care_application.process!
            expect(result).to eq(
              success: true, formSubmissionId: 40_124_668_140, timestamp: '2016-05-25T04:59:39.345-05:00'
            )
          end
        end
      end

      context 'with async compatible flag set' do
        it 'should save the record and submit async' do
          health_care_application.async_compatible = true
          expect(HCA::SubmissionJob).to receive(:perform_async)

          expect(health_care_application.process!).to eq(health_care_application)
          expect(health_care_application.id.present?).to eq(true)
        end
      end

      context 'when state changes to "failed"' do
        it 'should send a failure email to the email address provided on the form' do
          expect(health_care_application).to receive(:send_failure_mail).and_call_original
          expect(HCASubmissionFailureMailer).to receive(:build).and_call_original
          health_care_application.update_attributes!(state: 'failed')
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
