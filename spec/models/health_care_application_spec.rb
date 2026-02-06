# frozen_string_literal: true

require 'rails_helper'
require 'kafka/sidekiq/event_bus_submission_job'

RSpec.describe HealthCareApplication, type: :model do
  let(:health_care_application) { create(:health_care_application) }
  let(:health_care_application_short_form) do
    short_form = JSON.parse(health_care_application.form)
    short_form.delete('lastServiceBranch')
    short_form['vaCompensationType'] = 'highDisability'
    short_form
  end
  let(:inelig_character_of_discharge) { HCA::EnrollmentEligibility::Constants::INELIG_CHARACTER_OF_DISCHARGE }
  let(:statsd_key_prefix) { HCA::Service::STATSD_KEY_PREFIX }
  let(:zsf_tags) { described_class::DD_ZSF_TAGS }
  let(:form_id) { described_class::FORM_ID }

  before do
    allow(Flipper).to receive(:enabled?).with(:hca_ez_kafka_submission_enabled).and_return(true)
  end

  describe 'LOCKBOX' do
    it 'can encrypt strings over 4kb' do
      str = 'f' * 6000
      lockbox = described_class::LOCKBOX
      expect(lockbox.decrypt(lockbox.encrypt(str))).to eq(str)
    end
  end

  describe 'schema' do
    it 'is deep frozen' do
      expect do
        VetsJsonSchema::SCHEMAS['10-10EZ']['title'] = 'foo'
      end.to raise_error(FrozenError)

      expect(VetsJsonSchema::SCHEMAS['10-10EZ']['title']).to eq('APPLICATION FOR HEALTH BENEFITS (10-10EZ)')
    end
  end

  describe '#prefill_fields' do
    let(:health_care_application) { build(:health_care_application) }

    context 'with missing fields' do
      before do
        health_care_application.parsed_form.delete('veteranFullName')
        health_care_application.parsed_form.delete('veteranDateOfBirth')
        health_care_application.parsed_form.delete('veteranSocialSecurityNumber')
      end

      context 'without a user' do
        it 'does nothing' do
          expect(health_care_application.send(:prefill_fields)).to be_nil

          expect(health_care_application.valid?).to be(false)
        end
      end

      context 'with a user' do
        before do
          health_care_application.user = user
        end

        context 'with a loa1 user' do
          let(:user) { create(:user) }

          it 'does nothing' do
            expect(health_care_application.send(:prefill_fields)).to be_nil

            expect(health_care_application.valid?).to be(false)
          end
        end

        context 'with a loa3 user' do
          let(:user) { create(:user, :loa3) }

          context 'with a nil birth_date' do
            before do
              health_care_application.parsed_form['veteranDateOfBirth'] = '1923-01-02'
              expect(user).to receive(:birth_date).and_return(nil)
            end

            it 'doesnt set a field if the user data is null' do
              health_care_application.send(:prefill_fields)

              parsed_form = health_care_application.parsed_form
              expect(parsed_form['veteranDateOfBirth']).to eq('1923-01-02')
              expect(parsed_form['veteranSocialSecurityNumber']).to eq(user.ssn_normalized)
            end
          end

          it 'sets uneditable fields using user data' do
            expect(health_care_application.valid?).to be(false)
            health_care_application.send(:prefill_fields)
            expect(health_care_application.valid?).to be(true)

            parsed_form = health_care_application.parsed_form

            expect(parsed_form['veteranFullName']).to eq(user.full_name_normalized.compact.stringify_keys)
            expect(parsed_form['veteranDateOfBirth']).to eq(user.birth_date)
            expect(parsed_form['veteranSocialSecurityNumber']).to eq(user.ssn_normalized)
          end
        end
      end
    end
  end

  describe '.enrollment_status' do
    it 'returns parsed enrollment status' do
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
        effective_date: '2018-01-24T00:00:00.000-09:00',
        primary_eligibility: 'SC LESS THAN 50%'
      }
    end

    context 'with a loa3 user' do
      it 'returns the full parsed ee data' do
        expect(described_class.parsed_ee_data(ee_data, true)).to eq(
          application_date: '2018-01-24T00:00:00.000-06:00',
          enrollment_date: nil,
          preferred_facility: '987 - CHEY6',
          parsed_status: inelig_character_of_discharge,
          effective_date: '2018-01-24T00:00:00.000-09:00',
          primary_eligibility: 'SC LESS THAN 50%'
        )
      end

      context 'with an active duty service member' do
        let(:ee_data) do
          {
            enrollment_status: 'not applicable',
            application_date: '2018-01-24T00:00:00.000-06:00',
            enrollment_date: nil,
            preferred_facility: '987 - CHEY6',
            ineligibility_reason: 'OTH',
            primary_eligibility: 'TRICARE',
            veteran: 'false',
            effective_date: '2018-01-24T00:00:00.000-09:00'
          }
        end

        it 'returns the right parsed_status' do
          expect(described_class.parsed_ee_data(ee_data, true)[:parsed_status]).to eq(
            HCA::EnrollmentEligibility::Constants::ACTIVEDUTY
          )
        end
      end

      context 'when the user isnt active duty' do
        let(:ee_data) do
          {
            enrollment_status: 'not applicable',
            application_date: '2018-01-24T00:00:00.000-06:00',
            enrollment_date: nil,
            preferred_facility: '987 - CHEY6',
            ineligibility_reason: 'OTH',
            primary_eligibility: 'SC LESS THAN 50%',
            veteran: 'true',
            effective_date: '2018-01-24T00:00:00.000-09:00'
          }
        end

        it 'returns the right parsed_status' do
          expect(described_class.parsed_ee_data(ee_data, true)[:parsed_status]).to eq(
            HCA::EnrollmentEligibility::Constants::NON_MILITARY
          )
        end
      end
    end

    context 'with a loa1 user' do
      context 'when enrollment_status is present' do
        it 'returns partial ee data' do
          expect(described_class.parsed_ee_data(ee_data, false)).to eq(
            parsed_status: HCA::EnrollmentEligibility::Constants::LOGIN_REQUIRED
          )
        end
      end

      context 'when enrollment_status is not set' do
        it 'returns none of the above ee data' do
          expect(described_class.parsed_ee_data({}, false)).to eq(
            parsed_status: HCA::EnrollmentEligibility::Constants::NONE_OF_THE_ABOVE
          )
        end
      end
    end
  end

  describe '.user_icn' do
    let(:form) { health_care_application.parsed_form }

    context 'when the user is not found' do
      it 'returns nil' do
        expect_any_instance_of(MPI::Service).to receive(
          :find_profile_by_attributes
        ).and_return(
          create(:find_profile_not_found_response)
        )

        expect(described_class.user_icn(described_class.user_attributes(form))).to be_nil
      end
    end

    context 'when the user is found' do
      it 'returns the icn' do
        expect_any_instance_of(MPI::Service).to receive(
          :find_profile_by_attributes
        ).and_return(
          create(:find_profile_response, profile: OpenStruct.new(icn: '123'))
        )

        expect(described_class.user_icn(described_class.user_attributes(form))).to eq('123')
      end
    end
  end

  describe '.user_attributes' do
    subject(:user_attributes) do
      described_class.user_attributes(form)
    end

    let(:form) { health_care_application.parsed_form }

    it 'creates a mvi compatible hash of attributes' do
      expect(
        user_attributes.to_h
      ).to eq(
        first_name: 'FirstName',
        middle_name: 'MiddleName',
        last_name: 'ZZTEST',
        birth_date: '1923-01-02',
        ssn: '111111234'
      )
    end

    it 'creates user_attributes with uuid' do
      allow(SecureRandom).to receive(:uuid).and_return('my-uuid')
      expect(
        user_attributes.uuid
      ).to eq('my-uuid')
    end

    context 'with a nil form' do
      let(:form) { nil }

      it 'raises a validation error' do
        expect do
          user_attributes
        end.to raise_error(Common::Exceptions::ValidationErrors)
      end
    end
  end

  describe '#send_event_bus_event' do
    let(:health_care_application) { create(:health_care_application) }

    let(:user_attributes) do
      an_object_having_attributes(
        first_name: 'FirstName',
        middle_name: 'MiddleName',
        last_name: 'ZZTEST',
        birth_date: '1923-01-02',
        ssn: '111111234'
      )
    end

    context 'with a user' do
      let(:user) { create(:user) }

      before do
        health_care_application.user = user
      end

      it 'calls Kafka.submit event with the right arguments' do
        expect(Kafka).to receive(:submit_event).with(
          icn: user.icn,
          current_id: health_care_application.id,
          submission_name: 'F1010EZ', state: 'received',
          next_id: nil
        )

        health_care_application.send_event_bus_event('received')
      end

      context 'without an icn' do
        before do
          health_care_application.user = build(:user, icn: nil)
        end

        it 'falls back on looking up the user icn' do
          allow(described_class).to receive(:user_icn).with(user_attributes).and_return('123')

          expect(Kafka).to receive(:submit_event).with(
            icn: '123', current_id: health_care_application.id,
            submission_name: 'F1010EZ', state: 'sent',
            next_id: '456'
          )

          health_care_application.send_event_bus_event('sent', '456')
        end
      end
    end

    context 'without a user' do
      it 'returns the right payload' do
        allow(described_class).to receive(:user_icn).with(user_attributes).and_return('123')
        expect(Kafka).to receive(:submit_event).with(
          icn: '123', current_id: health_care_application.id,
          submission_name: 'F1010EZ', state: 'received', next_id: nil
        )

        health_care_application.send_event_bus_event('received')
      end

      it 'returns the right payload with a next id' do
        allow(described_class).to receive(:user_icn)
          .with(user_attributes).and_return('123')

        expect(Kafka).to receive(:submit_event).with(
          icn: '123', current_id: health_care_application.id,
          submission_name: 'F1010EZ', state: 'sent',
          next_id: '456'
        )

        health_care_application.send_event_bus_event('sent', '456')
      end

      context 'and invalid user attributes' do
        let(:invalid_user_attributes) { double(errors: ['error']) }

        before do
          allow(described_class).to receive(:user_attributes) \
            .and_raise(
              Common::Exceptions::ValidationErrors.new(invalid_user_attributes)
            )
        end

        it 'returns a payload with no ICN' do
          expect(Kafka).to receive(:submit_event).with(
            icn: nil, current_id: health_care_application.id,
            submission_name: 'F1010EZ', state: 'received', next_id: nil
          )

          health_care_application.send_event_bus_event('received')
        end
      end
    end

    context 'with the hca_ez_kafka_submission_enabled feature flag off' do
      before do
        allow(Flipper).to receive(:enabled?).with(:hca_ez_kafka_submission_enabled).and_return(false)
      end

      it 'does not call Kafka.submit_event' do
        expect(Kafka).not_to receive(:submit_event)

        health_care_application.send_event_bus_event('received')
      end
    end
  end

  describe 'validations' do
    context 'long form validations' do
      let(:health_care_application) { build(:health_care_application) }

      before do
        %w[
          maritalStatus
          isEnrolledMedicarePartA
          lastServiceBranch
          lastEntryDate
          lastDischargeDate
        ].each do |attr|
          health_care_application.parsed_form.delete(attr)
        end
      end

      context 'with a va compensation type of highDisability' do
        before do
          health_care_application.parsed_form['vaCompensationType'] = 'highDisability'
        end

        it 'doesnt require the long form fields' do
          expect(health_care_application.valid?).to be(true)
        end
      end

      context 'with a va compensation type of none' do
        before do
          health_care_application.parsed_form['vaCompensationType'] = 'none'
        end

        it 'allows false for boolean fields' do
          health_care_application.parsed_form['isEnrolledMedicarePartA'] = false

          health_care_application.valid?

          expect(health_care_application.errors[:form]).to eq(
            [
              "maritalStatus can't be null",
              "lastServiceBranch can't be null",
              "lastEntryDate can't be null",
              "lastDischargeDate can't be null"
            ]
          )
        end

        it 'requires the long form fields' do
          health_care_application.valid?
          expect(health_care_application.errors[:form]).to eq(
            [
              "maritalStatus can't be null",
              "isEnrolledMedicarePartA can't be null",
              "lastServiceBranch can't be null",
              "lastEntryDate can't be null",
              "lastDischargeDate can't be null"
            ]
          )
        end
      end
    end

    it 'validates presence of state' do
      health_care_application = described_class.new(state: nil)
      expect_attr_invalid(health_care_application, :state, "can't be blank")
    end

    it 'validates inclusion of state' do
      health_care_application = described_class.new

      %w[success error failed pending].each do |state|
        health_care_application.state = state
        expect_attr_valid(health_care_application, :state)
      end

      health_care_application.state = 'foo'
      expect_attr_invalid(health_care_application, :state, 'is not included in the list')
    end

    it 'validates presence of form_submission_id and timestamp if success' do
      health_care_application = described_class.new

      %w[form_submission_id_string timestamp].each do |attr|
        health_care_application.state = 'success'
        expect_attr_invalid(health_care_application, attr, "can't be blank")

        health_care_application.state = 'pending'
        expect_attr_valid(health_care_application, attr)
      end
    end

    context 'schema validation error' do
      let(:health_care_application) { build(:health_care_application) }
      let(:schema) { 'schema_content' }
      let(:schemer_errors) do
        [{
          data_pointer: 'data_pointer',
          error: 'some error',
          details: { detail: 'thing' },
          schema: { detail: 'schema' },
          root_schema: { detail: 'root_schema' },
          data: { key: 'this could be pii' }
        }]
      end

      before do
        allow(VetsJsonSchema::SCHEMAS).to receive(:[]).and_return(schema)
        allow(JSONSchemer).to receive(:schema).and_return(double(:fake_schema,
                                                                 validate: schemer_errors))
      end

      it 'sets errors' do
        health_care_application.valid?

        expect(health_care_application.errors[:form]).to eq ['some error']
      end
    end
  end

  describe '#process!' do
    let(:health_care_application) { build(:health_care_application) }

    before do
      allow_any_instance_of(MPI::Service).to receive(
        :find_profile_by_attributes
      ).and_return(
        create(:find_profile_response, profile: OpenStruct.new(icn: '123'))
      )
    end

    it 'calls prefill fields' do
      expect(health_care_application).to receive(:prefill_fields)

      health_care_application.process!
    end

    describe '#parsed_form overrides' do
      before do
        health_care_application.parsed_form.tap do |form|
          form['veteranAddress']['country'] = 'MEX'
          form['veteranAddress']['state'] = 'aguascalientes'
        end
      end

      it 'sets the proper abbreviation for states in Mexico' do
        expect(health_care_application).to receive(:prefill_fields)

        health_care_application.process!

        form = health_care_application.parsed_form
        expect(form['veteranAddress']['state']).to eq('AGS.')
      end
    end

    context 'with an invalid record' do
      it 'adds user loa to extra context' do
        expect(Sentry).to receive(:set_extras).with(user_loa: { current: 1, highest: 3 })

        expect do
          described_class.new(form: {}.to_json, user: build(:user)).process!
        end.to raise_error(Common::Exceptions::ValidationErrors)
      end

      it 'creates a PersonalInformationLog' do
        expect do
          described_class.new(form: { test: 'test' }.to_json).process!
        end.to raise_error(Common::Exceptions::ValidationErrors)

        personal_information_log = PersonalInformationLog.last
        expect(personal_information_log.data).to eq('test' => 'test')
        expect(personal_information_log.error_class).to eq('HealthCareApplication ValidationError')
      end

      it 'raises a validation error' do
        expect do
          described_class.new(form: {}.to_json).process!
        end.to raise_error(Common::Exceptions::ValidationErrors)
      end

      it 'triggers short form statsd' do
        expect do
          expect do
            described_class.new(form: { mothersMaidenName: 'm' }.to_json).process!
          end.to raise_error(Common::Exceptions::ValidationErrors)
        end.to trigger_statsd_increment("#{statsd_key_prefix}.validation_error_short_form")
      end

      it 'triggers statsd' do
        expect do
          expect do
            described_class.new(form: {}.to_json).process!
          end.to raise_error(Common::Exceptions::ValidationErrors)
        end.to trigger_statsd_increment("#{statsd_key_prefix}.validation_error")
      end

      it 'does not send "received" event' do
        allow(Kafka).to receive(:submit_event)
        expect(Kafka).not_to have_received(:submit_event)
        expect do
          described_class.new(form: {}.to_json).process!
        end.to raise_error(Common::Exceptions::ValidationErrors)
      end
    end

    def self.expect_job_submission(job)
      it "submits using the #{job}" do
        user = build(:user, edipi: 'my_edipi', icn: 'my_icn')
        allow_any_instance_of(HealthCareApplication).to receive(:id).and_return(1)
        allow_any_instance_of(HealthCareApplication).to receive(:user).and_return(user)
        expect_any_instance_of(HealthCareApplication).to receive(:save!)

        expect(job).to receive(:perform_async) do |
            user_identifier, encrypted_form, health_care_application_id, google_analytics_client_id
          |
          expect(user_identifier).to eq({ 'icn' => user.icn, 'edipi' => user.edipi })
          expect(HCA::SubmissionJob.decrypt_form(encrypted_form)).to eq(health_care_application.parsed_form)
          expect(health_care_application_id).to eq(1)
          expect(google_analytics_client_id).to be_nil
        end

        expect(health_care_application.process!).to eq(health_care_application)
      end
    end

    context 'with an email' do
      expect_job_submission(HCA::SubmissionJob)

      it 'sends the "received" event' do
        expect(Kafka).to receive(:submit_event).with(
          hash_including(state: 'received')
        )
        health_care_application.process!
      end
    end

    context 'with no email' do
      let(:service_instance) { instance_double(HCA::Service) }
      let(:parsed_form) { health_care_application.send(:parsed_form) }
      let(:success_result) { { success: true, formSubmissionId: '123', timestamp: Time.now.getlocal.to_s } }

      before do
        new_form = JSON.parse(health_care_application.form)
        new_form.delete('email')
        health_care_application.form = new_form.to_json
        health_care_application.instance_variable_set(:@parsed_form, nil)
        allow(HCA::Service).to receive(:new).and_return(service_instance)
      end

      context 'successful submission' do
        before do
          allow(service_instance).to receive(:submit_form)
            .with(parsed_form)
            .and_return(success_result)
        end

        it 'successfully submits synchronously' do
          expect(health_care_application.process!).to eq(success_result)
        end

        it 'saves the HCA record' do
          health_care_application.process!
          health_care_application.reload
          expect(health_care_application.id).not_to be_nil
          expect(health_care_application.state).to eq('success')
        end

        it 'sends the "received", and "sent" event' do
          expect(Kafka).to receive(:submit_event).with(
            hash_including(
              state: 'received',
              current_id: satisfy { |v| !v.nil? }
            )
          )
          expect(Kafka).to receive(:submit_event).with(
            hash_including(
              state: 'sent',
              next_id: '123',
              current_id: satisfy { |v| !v.nil? }
            )
          )
          health_care_application.process!
        end
      end

      context 'exception is raised in process!' do
        let(:client_error) { Common::Client::Errors::ClientError.new('error message flerp') }

        before do
          allow(StatsD).to receive(:increment)
          allow(service_instance).to receive(:submit_form)
            .and_raise(client_error)
        end

        it 'logs exception and raises BackendServiceException' do
          expect(Rails.logger).to receive(:error).with(
            '[10-10EZ] - Error synchronously submitting form',
            {
              exception: client_error, user_loa: nil
            }
          )
          expect(Rails.logger).to receive(:info).with(
            '[10-10EZ] - HCA total failure',
            {
              first_initial: 'F',
              middle_initial: 'M',
              last_initial: 'Z'
            }
          )

          expect do
            health_care_application.process!
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end

        it 'increments statsd' do
          expect(StatsD).to receive(:increment).with("#{statsd_key_prefix}.sync_submission_failed")

          expect do
            health_care_application.process!
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end

        it 'sends an error event to the Event Bus' do
          expect(Kafka).to receive(:submit_event).with(hash_including(state: 'received'))
          expect(Kafka).to receive(:submit_event).with(hash_including(state: 'error'))
          expect do
            health_care_application.process!
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end

        context 'short form' do
          before do
            health_care_application.form = health_care_application_short_form.to_json
            health_care_application.instance_variable_set(:@parsed_form, nil)
          end

          it 'increments statsd and short_form statsd' do
            expect(StatsD).to receive(:increment).with("#{statsd_key_prefix}.sync_submission_failed")
            expect(StatsD).to receive(:increment).with("#{statsd_key_prefix}.sync_submission_failed_short_form")

            expect do
              health_care_application.process!
            end.to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end
  end

  describe 'when state changes to "failed"' do
    subject do
      health_care_application.update!(state: 'failed')
      health_care_application
    end

    before do
      allow(VANotify::EmailJob).to receive(:perform_async)
      allow_any_instance_of(MPI::Service).to receive(
        :find_profile_by_attributes
      ).and_return(
        create(:find_profile_response, profile: OpenStruct.new(icn: '123'))
      )
    end

    describe '#send_failure_email' do
      context 'has form' do
        context 'with email address' do
          let(:email_address) { health_care_application.parsed_form['email'] }
          let(:api_key) { Settings.vanotify.services.health_apps_1010.api_key }
          let(:template_id) { Settings.vanotify.services.health_apps_1010.template_id.form1010_ez_failure_email }
          let(:callback_metadata) do
            {
              callback_metadata: {
                notification_type: 'error',
                form_number: form_id,
                statsd_tags: zsf_tags
              }
            }
          end

          let(:template_params) do
            [
              email_address,
              template_id,
              {
                'salutation' => "Dear #{health_care_application.parsed_form['veteranFullName']['first']},"
              },
              api_key,
              callback_metadata
            ]
          end

          let(:standard_error) { StandardError.new('Test error') }

          it 'sends a failure email to the email address provided on the form' do
            subject
            expect(VANotify::EmailJob).to have_received(:perform_async).with(*template_params)
          end

          it 'logs error if email job throws error' do
            allow(VANotify::EmailJob).to receive(:perform_async).and_raise(standard_error)
            allow(Rails.logger).to receive(:error)
            expect(Rails.logger).to receive(:error).with(
              '[10-10EZ] - Failure sending Submission Failure Email',
              { exception: standard_error }
            )
            expect(Rails.logger).to receive(:info).with(
              '[10-10EZ] - HCA total failure',
              {
                first_initial: 'F',
                middle_initial: 'M',
                last_initial: 'Z'
              }
            )
            expect { subject }.not_to raise_error
          end

          it 'increments statsd' do
            expect { subject }.to trigger_statsd_increment("#{statsd_key_prefix}.submission_failure_email_sent")
          end

          context 'without first name' do
            subject do
              health_care_application.parsed_form['veteranFullName'] = nil
              super()
            end

            let(:template_params_no_name) do
              [
                email_address,
                template_id,
                {
                  'salutation' => ''
                },
                api_key,
                callback_metadata
              ]
            end

            let(:standard_error) { StandardError.new('Test error') }

            it 'sends a failure email without personalisations to the email address provided on the form' do
              subject
              expect(VANotify::EmailJob).to have_received(:perform_async).with(*template_params_no_name)
            end

            it 'logs error if email job throws error' do
              allow(VANotify::EmailJob).to receive(:perform_async).and_raise(standard_error)
              allow(Rails.logger).to receive(:error)
              expect(Rails.logger).to receive(:error).with(
                '[10-10EZ] - Failure sending Submission Failure Email',
                { exception: standard_error }
              )
              expect(Rails.logger).to receive(:info).with(
                '[10-10EZ] - HCA total failure',
                {
                  first_initial: 'no initial provided',
                  middle_initial: 'no initial provided',
                  last_initial: 'no initial provided'
                }
              )
              expect { subject }.not_to raise_error
            end
          end
        end

        context 'without email address' do
          subject do
            health_care_application.parsed_form['email'] = nil
            super()
          end

          it 'does not send email' do
            expect(health_care_application).not_to receive(:send_failure_email)
            subject
          end
        end
      end

      context 'does not have form' do
        subject do
          health_care_application.form = nil
          super()
        end

        context 'with email address' do
          it 'does not send email' do
            expect(health_care_application).not_to receive(:send_failure_email)
            subject
          end
        end

        context 'without email address' do
          subject do
            health_care_application.parsed_form['email'] = nil
            super()
          end

          it 'does not send email' do
            expect(health_care_application).not_to receive(:send_failure_email)
            subject
          end
        end
      end
    end

    describe '#log_async_submission_failure' do
      it 'triggers failed_wont_retry statsd' do
        expect { subject }.to trigger_statsd_increment("#{statsd_key_prefix}.failed_wont_retry")
      end

      context 'short form' do
        before do
          health_care_application.form = health_care_application_short_form.to_json
          health_care_application.instance_variable_set(:@parsed_form, nil)
        end

        it 'triggers statsd' do
          expect { subject }.to trigger_statsd_increment("#{statsd_key_prefix}.failed_wont_retry")
            .and trigger_statsd_increment("#{statsd_key_prefix}.failed_wont_retry_short_form")
        end
      end

      context 'form is present' do
        it 'logs form to PersonalInformationLog' do
          subject
          pii_log = PersonalInformationLog.last
          expect(pii_log.error_class).to eq('HealthCareApplication FailedWontRetry')
          expect(pii_log.data).to eq(health_care_application.parsed_form)
        end

        it 'logs message' do
          expect(Rails.logger).to receive(:info).with(
            '[10-10EZ] - HCA total failure',
            {
              first_initial: 'F',
              middle_initial: 'M',
              last_initial: 'Z'
            }
          )

          subject
        end

        it 'sends the "error" event to the Event Bus' do
          expect(Kafka).to receive(:submit_event).with(hash_including(state: 'error'))
          subject
        end
      end

      context 'hca_ez_kafka_submission_enabled feature flag off' do
        before do
          allow(Flipper).to receive(:enabled?).with(:hca_ez_kafka_submission_enabled).and_return(false)
        end

        it 'does not send the "error" event to the Event Bus' do
          expect(Kafka).not_to receive(:submit_event).with(hash_including(state: 'error'))
          subject
        end
      end

      context '@parsed_form is nil' do
        before do
          health_care_application.instance_variable_set(:@parsed_form, nil)
        end

        context 'form is empty' do
          before do
            health_care_application.form = {}.to_json
          end

          it 'does not log form to PersonalInformationLog' do
            subject
            expect(PersonalInformationLog.count).to eq 0
          end

          it 'does not log message' do
            expect(Rails.logger).not_to receive(:error)
            subject
          end
        end

        context 'form does not have veteranFullName' do
          before do
            health_care_application.form = { email: 'my_email@email.com' }.to_json
          end

          it 'logs form to PersonalInformationLog' do
            subject
            pii_log = PersonalInformationLog.last
            expect(pii_log.error_class).to eq('HealthCareApplication FailedWontRetry')
            expect(pii_log.data).to eq(health_care_application.parsed_form)
          end

          it 'logs message' do
            expect(Rails.logger).to receive(:info).with(
              '[10-10EZ] - HCA total failure',
              {
                first_initial: 'no initial provided',
                middle_initial: 'no initial provided',
                last_initial: 'no initial provided'
              }
            )
            subject
          end
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

    before do
      allow_any_instance_of(MPI::Service).to receive(
        :find_profile_by_attributes
      ).and_return(
        create(:find_profile_response, profile: OpenStruct.new(icn: '123'))
      )
    end

    it 'sets the right fields and save the application' do
      health_care_application = build(:health_care_application)
      health_care_application.set_result_on_success!(result)

      expect(health_care_application.id.present?).to be(true)
      expect(health_care_application.success?).to be(true)
      expect(health_care_application.form_submission_id).to eq(result[:formSubmissionId])
      expect(health_care_application.timestamp).to eq(result[:timestamp])
    end

    it 'sends the "sent" event to the Event Bus' do
      health_care_application = build(:health_care_application)

      expect(Kafka).to receive(:submit_event).with(
        hash_including(
          state: 'sent',
          next_id: result[:formSubmissionId].to_s
        )
      )

      health_care_application.set_result_on_success!(result)
    end

    context 'hca_ez_kafka_submission_enabled feature flag off' do
      before do
        allow(Flipper).to receive(:enabled?).with(:hca_ez_kafka_submission_enabled).and_return(false)
      end

      it 'does not send the "sent" event to the Event Bus' do
        health_care_application = build(:health_care_application)

        expect(Kafka).not_to receive(:submit_event).with(
          hash_including(state: 'sent')
        )

        health_care_application.set_result_on_success!(result)
      end
    end
  end

  describe '#parsed_form' do
    subject { health_care_application.parsed_form }

    let(:form) { Rails.root.join('spec', 'fixtures', 'hca', 'veteran.json').read }

    context '@parsed_form is already set' do
      it 'returns parsed_form' do
        expect(subject).to eq JSON.parse(form)
      end

      context 'form is nil' do
        before do
          health_care_application.form = nil
        end

        it 'returns parsed_form' do
          expect(subject).to eq JSON.parse(form)
        end
      end
    end

    context '@parsed_form is nil' do
      before do
        health_care_application.instance_variable_set(:@parsed_form, nil)
      end

      it 'returns parsed form' do
        expect(subject).to eq JSON.parse(form)
      end

      context 'form is nil' do
        before do
          health_care_application.form = nil
        end

        it 'returns nil' do
          expect(subject).to be_nil
        end
      end
    end
  end

  describe '#form_id' do
    it 'has form_id from FORM_ID const' do
      expect(health_care_application.form_id).to eq described_class::FORM_ID
    end
  end
end
