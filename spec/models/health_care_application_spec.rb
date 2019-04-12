# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthCareApplication, type: :model do
  let(:health_care_application) { create(:health_care_application) }
  let(:inelig_character_of_discharge) { HCA::EnrollmentEligibility::ParsedStatuses::INELIG_CHARACTER_OF_DISCHARGE }
  let(:login_required) { HCA::EnrollmentEligibility::ParsedStatuses::LOGIN_REQUIRED }

  describe '.enrollment_status' do
    it 'should return parsed enrollment status' do
      expect_any_instance_of(HCA::EnrollmentEligibility::Service).to receive(:lookup_user).with(
        '123'
      ).and_return(
        enrollment_status: 'Not Eligible; Ineligible Date',
        application_date: '2018-01-24T00:00:00.000-06:00',
        enrollment_date: nil,
        preferred_facility: '987 - CHEY6',
        ineligibility_reason: 'OTH',
        effective_date: '2018-01-24T00:00:00.000-09:00'
      )
      expect(described_class.enrollment_status('123', true)).to eq(
        application_date: '2018-01-24T00:00:00.000-06:00',
        enrollment_date: nil,
        preferred_facility: '987 - CHEY6',
        parsed_status: inelig_character_of_discharge,
        effective_date: '2018-01-24T00:00:00.000-09:00'
      )
    end
  end

  describe '.parsed_ee_data' do
    let(:ee_data) do
      {
        enrollment_status: 'Not Eligible; Ineligible Date',
        application_date: '2018-01-24T00:00:00.000-06:00',
        enrollment_date: nil,
        preferred_facility: '987 - CHEY6',
        ineligibility_reason: 'OTH',
        effective_date: '2018-01-24T00:00:00.000-09:00'
      }
    end

    context 'with a loa3 user' do
      it 'should return the full parsed ee data' do
        expect(described_class.parsed_ee_data(ee_data, true)).to eq(
          application_date: '2018-01-24T00:00:00.000-06:00',
          enrollment_date: nil,
          preferred_facility: '987 - CHEY6',
          parsed_status: inelig_character_of_discharge,
          effective_date: '2018-01-24T00:00:00.000-09:00'
        )
      end
    end

    context 'with a loa1 user' do
      it 'should return partial ee data' do
        expect(described_class.parsed_ee_data(ee_data, false)).to eq(
          parsed_status: login_required
        )
      end
    end
  end

  describe '.user_icn' do
    let(:form) { health_care_application.parsed_form }

    context 'when the user is not found' do
      it 'should return nil' do
        expect_any_instance_of(MVI::Service).to receive(
          :perform
        ).and_raise(MVI::Errors::RecordNotFound)

        expect(described_class.user_icn(described_class.user_attributes(form))).to eq(nil)
      end
    end

    context 'when the user is found' do
      it 'should return the icn' do
        expect_any_instance_of(MVI::Service).to receive(
          :find_profile
        ).and_return(
          OpenStruct.new(
            profile: OpenStruct.new(icn: '123')
          )
        )

        expect(described_class.user_icn(described_class.user_attributes(form))).to eq('123')
      end
    end
  end

  describe '.user_attributes' do
    it 'should create a mvi compatible hash of attributes' do
      expect(
        described_class.user_attributes(
          health_care_application.parsed_form
        ).to_h
      ).to eq(
        first_name: 'FirstName', middle_name: 'MiddleName',
        last_name: 'ZZTEST', birth_date: '1923-01-02',
        ssn: '111111234'
      )
    end
  end

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
