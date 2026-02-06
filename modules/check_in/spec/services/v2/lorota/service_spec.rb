# frozen_string_literal: true

require 'rails_helper'

describe V2::Lorota::Service do
  subject { described_class }

  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:opts) do
    {
      data: {
        uuid: id,
        dob: '1970-02-20',
        last_name: 'Johnson'
      }
    }
  end
  let(:valid_check_in) { CheckIn::V2::Session.build(opts) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:appointment_data) do
    {
      id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
      scope: 'read.full',
      payload: {
        demographics: {
          nextOfKin1: {
            name: 'VETERAN,JONAH',
            relationship: 'BROTHER',
            phone: '1112223333',
            workPhone: '4445556666',
            address: {
              street1: '123 Main St',
              street2: 'Ste 234',
              street3: '',
              city: 'Los Angeles',
              county: 'Los Angeles',
              state: 'CA',
              zip: '90089',
              zip4: nil,
              country: 'USA'
            }
          },
          nextOfKin2: {
            name: '',
            relationship: '',
            phone: '',
            workPhone: '',
            address: {
              street1: '',
              street2: '',
              street3: '',
              city: '',
              county: nil,
              state: '',
              zip: '',
              zip4: nil,
              country: nil
            }
          },
          emergencyContact: {
            name: 'VETERAN,JONAH',
            relationship: 'BROTHER',
            phone: '1112223333',
            workPhone: '4445556666',
            address: {
              street1: '123 Main St',
              street2: 'Ste 234',
              street3: '',
              city: 'Los Angeles',
              county: 'Los Angeles',
              state: 'CA',
              zip: '90089',
              zip4: nil,
              country: 'USA'
            }
          },
          mailingAddress: {
            street1: '123 Turtle Trail',
            street2: '',
            street3: '',
            city: 'Treetopper',
            county: 'SAN BERNARDINO',
            state: 'Tennessee',
            zip: '101010',
            country: 'USA'
          },
          homeAddress: {
            street1: '445 Fine Finch Fairway',
            street2: 'Apt 201',
            street3: '',
            city: 'Fairfence',
            county: 'FOO',
            state: 'Florida',
            zip: '445545',
            country: 'USA'
          },
          homePhone: '5552223333',
          mobilePhone: '5553334444',
          workPhone: '5554445555',
          emailAddress: 'kermit.frog@sesameenterprises.us'
        },
        appointments: [
          {
            appointmentIEN: '460',
            checkedInTime: '',
            checkInSteps: {},
            checkInWindowEnd: '2021-12-23T08:40:00.000-05:00',
            checkInWindowStart: '2021-12-23T08:00:00.000-05:00',
            clinicCreditStopCodeName: 'SOCIAL WORK SERVICE',
            clinicFriendlyName: 'Health Wellness',
            clinicIen: 500,
            clinicLocation: 'ATLANTA VAMC',
            clinicName: 'Family Wellness',
            clinicPhoneNumber: '555-555-5555',
            clinicStopCodeName: 'PRIMARY CARE/MEDICINE',
            doctorName: '',
            eligibility: 'ELIGIBLE',
            facility: 'VEHU DIVISION',
            kind: 'clinic',
            patientDFN: '888',
            startTime: '2021-12-23T08:30:00',
            stationNo: 5625,
            status: ''
          },
          {
            appointmentIEN: '461',
            checkedInTime: '',
            checkInSteps: {},
            checkInWindowEnd: '2021-12-23T09:40:00.000-05:00',
            checkInWindowStart: '2021-12-23T09:00:00.000-05:00',
            clinicCreditStopCodeName: 'SOCIAL WORK SERVICE',
            clinicFriendlyName: 'CARDIOLOGY',
            clinicIen: 500,
            clinicLocation: 'ATLANTA VAMC',
            clinicName: 'CARDIOLOGY',
            clinicPhoneNumber: '555-555-5555',
            clinicStopCodeName: 'PRIMARY CARE/MEDICINE',
            doctorName: '',
            eligibility: 'ELIGIBLE',
            facility: 'CARDIO DIVISION',
            kind: 'phone',
            patientDFN: '888',
            startTime: '2021-12-23T09:30:00',
            stationNo: 5625,
            status: ''
          }
        ],
        patientDemographicsStatus: {
          demographicsNeedsUpdate: true,
          demographicsConfirmedAt: nil,
          nextOfKinNeedsUpdate: false,
          nextOfKinConfirmedAt: '2021-12-10T05:15:00.000-05:00',
          emergencyContactNeedsUpdate: true,
          emergencyContactConfirmedAt: '2021-12-10T05:30:00.000-05:00'
        }
      }
    }
  end
  let(:approved_response) do
    {
      payload: {
        address: nil,
        demographics: {
          mailingAddress: {
            street1: '123 Turtle Trail',
            street2: '',
            street3: '',
            city: 'Treetopper',
            county: 'SAN BERNARDINO',
            state: 'Tennessee',
            zip: '101010',
            zip4: nil,
            country: 'USA'
          },
          homeAddress: {
            street1: '445 Fine Finch Fairway',
            street2: 'Apt 201',
            street3: '',
            city: 'Fairfence',
            county: 'FOO',
            state: 'Florida',
            zip: '445545',
            zip4: nil,
            country: 'USA'
          },
          homePhone: '5552223333',
          mobilePhone: '5553334444',
          workPhone: '5554445555',
          emailAddress: 'kermit.frog@sesameenterprises.us',
          nextOfKin1: {
            name: 'VETERAN,JONAH',
            relationship: 'BROTHER',
            phone: '1112223333',
            workPhone: '4445556666',
            address: {
              street1: '123 Main St',
              street2: 'Ste 234',
              street3: '',
              city: 'Los Angeles',
              county: 'Los Angeles',
              state: 'CA',
              zip: '90089',
              zip4: nil,
              country: 'USA'
            }
          },
          emergencyContact: {
            name: 'VETERAN,JONAH',
            relationship: 'BROTHER',
            phone: '1112223333',
            workPhone: '4445556666',
            address: {
              street1: '123 Main St',
              street2: 'Ste 234',
              street3: '',
              city: 'Los Angeles',
              county: 'Los Angeles',
              state: 'CA',
              zip: '90089',
              zip4: nil,
              country: 'USA'
            }
          }
        },
        appointments: [
          {
            'appointmentIEN' => '460',
            'checkedInTime' => '',
            'checkInSteps' => {},
            'checkInWindowEnd' => '2021-12-23T08:40:00.000-05:00',
            'checkInWindowStart' => '2021-12-23T08:00:00.000-05:00',
            'clinicCreditStopCodeName' => 'SOCIAL WORK SERVICE',
            'clinicFriendlyName' => 'Health Wellness',
            'clinicIen' => 500,
            'clinicLocation' => 'ATLANTA VAMC',
            'clinicName' => 'Family Wellness',
            'clinicPhoneNumber' => '555-555-5555',
            'clinicStopCodeName' => 'PRIMARY CARE/MEDICINE',
            'doctorName' => '',
            'eligibility' => 'ELIGIBLE',
            'facility' => 'VEHU DIVISION',
            'kind' => 'clinic',
            'startTime' => '2021-12-23T08:30:00',
            'stationNo' => 5625,
            'status' => ''
          },
          {
            'appointmentIEN' => '461',
            'checkedInTime' => '',
            'checkInSteps' => {},
            'checkInWindowEnd' => '2021-12-23T09:40:00.000-05:00',
            'checkInWindowStart' => '2021-12-23T09:00:00.000-05:00',
            'clinicCreditStopCodeName' => 'SOCIAL WORK SERVICE',
            'clinicFriendlyName' => 'CARDIOLOGY',
            'clinicIen' => 500,
            'clinicLocation' => 'ATLANTA VAMC',
            'clinicName' => 'CARDIOLOGY',
            'clinicPhoneNumber' => '555-555-5555',
            'clinicStopCodeName' => 'PRIMARY CARE/MEDICINE',
            'doctorName' => '',
            'eligibility' => 'ELIGIBLE',
            'facility' => 'CARDIO DIVISION',
            'kind' => 'phone',
            'startTime' => '2021-12-23T09:30:00',
            'stationNo' => 5625,
            'status' => ''
          }
        ],
        patientDemographicsStatus: {
          demographicsNeedsUpdate: true,
          demographicsConfirmedAt: nil,
          nextOfKinNeedsUpdate: false,
          nextOfKinConfirmedAt: '2021-12-10T05:15:00.000-05:00',
          emergencyContactNeedsUpdate: true,
          emergencyContactConfirmedAt: '2021-12-10T05:30:00.000-05:00'
        },
        setECheckinStartedCalled: nil
      },
      id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d'
    }
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled')
                                        .and_return(false)

    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build(check_in: valid_check_in)).to be_an_instance_of(V2::Lorota::Service)
    end
  end

  describe '#token' do
    let(:token) { 'abc123' }
    let(:token_response) do
      {
        permission_data: {
          permissions: 'read.full',
          uuid: id,
          status: 'success'
        },
        jwt: token
      }
    end

    context 'when lorota token endpoint call succeeds' do
      before do
        allow_any_instance_of(V2::Lorota::Client).to receive(:token)
          .and_return(Faraday::Response.new(response_body: { token: }.to_json, status: 200))
      end

      it 'returns data from lorota' do
        expect(subject.build(check_in: valid_check_in).token).to eq(token_response)
      end
    end

    context 'when lorota token endpoint call fails' do
      let(:last_name_mismatch) do
        '{ "error" : "lastName does not match with current record" }'
      end
      let(:dob_mismatch_with_whitespace) { '{ "error" : "  dob does not match with current record   " }' }
      let(:dob_mismatch) { '{ "error" : "dob does not match with current record" }' }
      let(:last_name_dob_mismatch) { '{ "error" : "lastName or dob does not match with current record" }' }
      let(:uuid_not_found) { '{ "error" : "UUID not found" }' }
      let(:unknown_issuer) { '{ "error" : "unknown issuer" }' }
      let(:retry_count) { 1 }
      let(:auth_exception_response_values) do
        { title: 'Authentication Error', detail: 'Authentication Error', code: 'LOROTA-API_401', status: 401 }
      end
      let(:uuid_not_found_exception) do
        { status: '404', detail: ['{ "error" : "UUID not found" }'], code: 'CIE-VETS-API_404' }
      end

      context 'with chip delete endpoint succeeding' do
        before do
          allow_any_instance_of(V2::Chip::Service).to receive(:delete)
            .and_return(Faraday::Response.new(response_body: 'Delete successful', status: 200))
        end

        context 'when status code is 401 with lastName does not match error message' do
          before do
            allow_any_instance_of(V2::Lorota::Client).to receive(:token)
              .and_raise(Common::Exceptions::BackendServiceException.new('LOROTA-API_401',
                                                                         auth_exception_response_values,
                                                                         401, last_name_mismatch))
          end

          context 'if redis retry_attempt < max_auth_retry_limit' do
            before do
              Rails.cache.write(
                "authentication_retry_limit_#{id}",
                retry_count,
                namespace: 'check-in-lorota-v2-cache',
                expires_in: 604_800
              )
            end

            it 'increments retry_attempt_count and returns authentication error' do
              expect do
                subject.build(check_in: valid_check_in).token
              end.to raise_error(Common::Exceptions::BackendServiceException,
                                 "BackendServiceException: #{auth_exception_response_values}")

              retry_attempt_count = Rails.cache.read(
                "authentication_retry_limit_#{id}",
                namespace: 'check-in-lorota-v2-cache'
              )

              expect(retry_attempt_count).to eq(retry_count + 1)
            end
          end

          context 'if redis retry_attempt >= max_auth_retry_limit' do
            let(:data_gone_exception) do
              { status: '410', detail: [last_name_mismatch], code: 'CIE-VETS-API_410' }
            end

            before do
              Rails.cache.write(
                "authentication_retry_limit_#{id}",
                retry_count + 3,
                namespace: 'check-in-lorota-v2-cache',
                expires_in: 604_800
              )
            end

            it 'throws exception with 410 status code' do
              expect do
                subject.build(check_in: valid_check_in).token
              end.to raise_error(CheckIn::V2::CheckinServiceException,
                                 "BackendServiceException: #{data_gone_exception}")
            end
          end
        end

        context 'when status code is 401 with DOB does not match error message for second retry' do
          before do
            allow_any_instance_of(V2::Lorota::Client).to receive(:token)
              .and_raise(Common::Exceptions::BackendServiceException.new('LOROTA-API_401',
                                                                         auth_exception_response_values,
                                                                         401,
                                                                         dob_mismatch))
          end

          context 'if redis retry_attempt < max_auth_retry_limit' do
            before do
              Rails.cache.write(
                "authentication_retry_limit_#{id}",
                retry_count,
                namespace: 'check-in-lorota-v2-cache',
                expires_in: 604_800
              )
            end

            it 'increments retry_attempt_count and returns authentication error' do
              expect do
                subject.build(check_in: valid_check_in).token
              end.to raise_error(Common::Exceptions::BackendServiceException,
                                 "BackendServiceException: #{auth_exception_response_values}")

              retry_attempt_count = Rails.cache.read(
                "authentication_retry_limit_#{id}",
                namespace: 'check-in-lorota-v2-cache'
              )
              expect(retry_attempt_count).to eq(retry_count + 1)
            end
          end

          context 'if redis retry_attempt >= max_auth_retry_limit' do
            let(:data_gone_exception) do
              { status: '410', detail: [dob_mismatch], code: 'CIE-VETS-API_410' }
            end

            before do
              Rails.cache.write(
                "authentication_retry_limit_#{id}",
                retry_count + 3,
                namespace: 'check-in-lorota-v2-cache',
                expires_in: 604_800
              )
            end

            it 'throws exception with 410 status code' do
              expect do
                subject.build(check_in: valid_check_in).token
              end.to raise_error(CheckIn::V2::CheckinServiceException,
                                 "BackendServiceException: #{data_gone_exception}")
            end
          end
        end

        context 'when status code is 401 with last name and DOB mismatch error message' do
          before do
            allow_any_instance_of(V2::Lorota::Client).to receive(:token)
              .and_raise(Common::Exceptions::BackendServiceException.new('LOROTA-API_401',
                                                                         auth_exception_response_values,
                                                                         401,
                                                                         last_name_dob_mismatch))
          end

          context 'if redis retry_attempt < max_auth_retry_limit' do
            before do
              Rails.cache.write(
                "authentication_retry_limit_#{id}",
                retry_count,
                namespace: 'check-in-lorota-v2-cache',
                expires_in: 604_800
              )
            end

            it 'increments retry_attempt_count and returns authentication error' do
              expect do
                subject.build(check_in: valid_check_in).token
              end.to raise_error(Common::Exceptions::BackendServiceException,
                                 "BackendServiceException: #{auth_exception_response_values}")

              retry_attempt_count = Rails.cache.read(
                "authentication_retry_limit_#{id}",
                namespace: 'check-in-lorota-v2-cache'
              )
              expect(retry_attempt_count).to eq(retry_count + 1)
            end
          end

          context 'if redis retry_attempt >= max_auth_retry_limit' do
            let(:data_gone_exception) do
              { status: '410', detail: [last_name_dob_mismatch], code: 'CIE-VETS-API_410' }
            end

            before do
              Rails.cache.write(
                "authentication_retry_limit_#{id}",
                retry_count + 3,
                namespace: 'check-in-lorota-v2-cache',
                expires_in: 604_800
              )
            end

            it 'throws exception with 410 status code' do
              expect do
                subject.build(check_in: valid_check_in).token
              end.to raise_error(CheckIn::V2::CheckinServiceException,
                                 "BackendServiceException: #{data_gone_exception}")
            end
          end
        end

        context 'when status code is 401 with leading and trailing whitespaces in error message' do
          before do
            allow_any_instance_of(V2::Lorota::Client).to receive(:token)
              .and_raise(Common::Exceptions::BackendServiceException.new('LOROTA-API_401',
                                                                         auth_exception_response_values,
                                                                         401, dob_mismatch_with_whitespace))
          end

          context 'if redis retry_attempt < max_auth_retry_limit' do
            before do
              Rails.cache.write(
                "authentication_retry_limit_#{id}",
                retry_count,
                namespace: 'check-in-lorota-v2-cache',
                expires_in: 604_800
              )
            end

            it 'still increments retry_attempt_count and returns authentication error' do
              expect do
                subject.build(check_in: valid_check_in).token
              end.to raise_error(Common::Exceptions::BackendServiceException,
                                 "BackendServiceException: #{auth_exception_response_values}")

              retry_attempt_count = Rails.cache.read(
                "authentication_retry_limit_#{id}",
                namespace: 'check-in-lorota-v2-cache'
              )
              expect(retry_attempt_count).to eq(retry_count + 1)
            end
          end
        end

        context 'when status code is 401 with unknown issuer error message' do
          before do
            allow_any_instance_of(V2::Lorota::Client).to receive(:token)
              .and_raise(Common::Exceptions::BackendServiceException.new('LOROTA-API_401',
                                                                         auth_exception_response_values,
                                                                         401,
                                                                         unknown_issuer))
          end

          context 'if redis retry_attempt < max_auth_retry_limit' do
            it 'returns authentication error without incrementing retry_attempts' do
              expect do
                subject.build(check_in: valid_check_in).token
              end.to raise_error(Common::Exceptions::BackendServiceException,
                                 "BackendServiceException: #{auth_exception_response_values}")

              retry_attempt_count = Rails.cache.read(
                "authentication_retry_limit_#{id}",
                namespace: 'check-in-lorota-v2-cache'
              )
              expect(retry_attempt_count).to be_nil
            end
          end
        end

        context 'when status code is 401 with max_auth_retry_limit as string' do
          before do
            allow_any_instance_of(V2::Lorota::Client).to receive(:token)
              .and_raise(Common::Exceptions::BackendServiceException.new('LOROTA-API_401',
                                                                         auth_exception_response_values,
                                                                         401,
                                                                         last_name_mismatch))
            allow_any_instance_of(V2::Lorota::Service).to receive(:max_auth_retry_limit).and_return('3')
            Rails.cache.write(
              "authentication_retry_limit_#{id}",
              retry_count,
              namespace: 'check-in-lorota-v2-cache',
              expires_in: 604_800
            )
          end

          it 'treats max_auth_retry_limit as integer and increments entry in redis' do
            expect do
              subject.build(check_in: valid_check_in).token
            end.to raise_error(Common::Exceptions::BackendServiceException,
                               "BackendServiceException: #{auth_exception_response_values}")

            retry_attempt_count = Rails.cache.read(
              "authentication_retry_limit_#{id}",
              namespace: 'check-in-lorota-v2-cache'
            )
            expect(retry_attempt_count).to eq(retry_count + 1)
          end
        end

        context 'when status code is 401 with UUID not found error message' do
          before do
            allow_any_instance_of(V2::Lorota::Client).to receive(:token)
              .and_raise(Common::Exceptions::BackendServiceException.new('LOROTA-API_401',
                                                                         auth_exception_response_values,
                                                                         401,
                                                                         uuid_not_found))
          end

          it 'throws exception with 404 status code' do
            expect do
              subject.build(check_in: valid_check_in).token
            end.to raise_error(CheckIn::V2::CheckinServiceException,
                               "BackendServiceException: #{uuid_not_found_exception}")
          end
        end
      end

      context 'with chip delete endpoint failing' do
        let(:data_gone_exception) do
          { status: '410', detail: [last_name_mismatch], code: 'CIE-VETS-API_410' }
        end

        before do
          allow_any_instance_of(V2::Lorota::Client).to receive(:token)
            .and_raise(Common::Exceptions::BackendServiceException.new('LOROTA-API_401',
                                                                       auth_exception_response_values,
                                                                       401, last_name_mismatch))
          allow_any_instance_of(V2::Chip::Service).to receive(:delete)
            .and_return(Faraday::Response.new(response_body: 'Unknown error',
                                              status: 500))
          Rails.cache.write(
            "authentication_retry_limit_#{id}",
            retry_count + 3,
            namespace: 'check-in-lorota-v2-cache',
            expires_in: 604_800
          )
        end

        it 'throws exception with 410 status code' do
          expect do
            subject.build(check_in: valid_check_in).token
          end.to raise_error(CheckIn::V2::CheckinServiceException,
                             "BackendServiceException: #{data_gone_exception}")
        end
      end

      context 'when status code is 400 with internal service exception from downstream' do
        let(:internal_service_exception) do
          { status: 400, detail: 'Internal Error', code: 'VA900' }
        end

        before do
          allow_any_instance_of(V2::Lorota::Client).to receive(:token)
            .and_raise(Common::Exceptions::BackendServiceException.new('VA900',
                                                                       internal_service_exception,
                                                                       500,
                                                                       'Request timed out'))
        end

        it 'returns error without incrementing retry_attempts' do
          expect do
            subject.build(check_in: valid_check_in).token
          end.to raise_error(Common::Exceptions::BackendServiceException,
                             "BackendServiceException: #{internal_service_exception}")

          retry_attempt_count = Rails.cache.read(
            "authentication_retry_limit_#{id}",
            namespace: 'check-in-lorota-v2-cache'
          )
          expect(retry_attempt_count).to be_nil
        end
      end
    end
  end

  describe '#check_in_data' do
    before do
      allow_any_instance_of(V2::Lorota::RedisClient).to receive(:get).and_return('123abc')
      allow_any_instance_of(V2::Lorota::Client).to receive(:data)
        .and_return(Faraday::Response.new(response_body: appointment_data.to_json, status: 200))
    end

    it 'returns approved data' do
      expect(subject.build(check_in: valid_check_in).check_in_data).to eq(approved_response)
    end

    context 'when check_in_type is preCheckIn' do
      let(:opts) { { data: { check_in_type: 'preCheckIn' } } }
      let(:pre_check_in) { CheckIn::V2::Session.build(opts) }

      it 'does not save appointment identifiers' do
        expect_any_instance_of(CheckIn::V2::PatientCheckIn).not_to receive(:save)

        subject.build(check_in: pre_check_in).check_in_data
      end
    end

    context 'when check_in_type is not preCheckIn' do
      let(:opts) { { data: { check_in_type: 'anything else' } } }
      let(:check_in) { CheckIn::V2::Session.build(opts) }

      it 'saves appointment identifiers' do
        expect_any_instance_of(CheckIn::V2::PatientCheckIn).to receive(:save).once

        subject.build(check_in:).check_in_data
      end
    end

    context 'when appt identifiers are not present' do
      it 'does not call refresh_appts' do
        expect_any_instance_of(V2::Chip::Service).not_to receive(:refresh_appointments)

        expect(subject.build(check_in: valid_check_in).check_in_data).to eq(approved_response)
      end
    end

    context 'when appt identifiers are present and facility type is OH' do
      let(:valid_check_in_oh) { CheckIn::V2::Session.build(opts.deep_merge!({ data: { facility_type: 'oh' } })) }

      before do
        Rails.cache.write(
          "check_in_lorota_v2_appointment_identifiers_#{id}",
          '123',
          namespace: 'check-in-lorota-v2-cache'
        )
      end

      it 'does not call refresh_appts' do
        expect_any_instance_of(V2::Chip::Service).not_to receive(:refresh_appointments)

        expect(subject.build(check_in: valid_check_in_oh).check_in_data).to eq(approved_response)
      end
    end
  end

  describe '#parse_check_in_response_data' do
    let(:service_instance) { subject.build(check_in: valid_check_in) }

    context 'when JSON parsing succeeds' do
      let(:raw_data) do
        double('FaradayResponse', body: appointment_data.to_json)
      end

      it 'returns appointments and demographics status' do
        appointments, demographics_status = service_instance.send(:parse_check_in_response_data, raw_data)

        expect(appointments).to be_an(Array)
        expect(appointments.size).to eq(2)
        expect(demographics_status).to be_a(Hash)
        expect(demographics_status['demographicsNeedsUpdate']).to be true
      end
    end

    context 'when Oj::ParseError occurs' do
      let(:raw_data) { double('FaradayResponse', body: 'invalid json {') }

      before do
        allow(Oj).to receive(:load).and_raise(Oj::ParseError.new('Invalid JSON'))
      end

      it 'logs a warning and returns empty arrays' do
        expect(Rails.logger).to receive(:warn).with(
          {
            message: 'JSON parsing failed',
            check_in_uuid: id,
            error: 'Invalid JSON'
          }
        )

        appointments, demographics_status = service_instance.send(:parse_check_in_response_data, raw_data)

        expect(appointments).to eq([])
        expect(demographics_status).to eq({})
      end
    end

    context 'when EncodingError occurs' do
      let(:raw_data) { double('FaradayResponse', body: 'some data') }

      before do
        allow(Oj).to receive(:load).and_raise(EncodingError.new('Invalid encoding'))
      end

      it 'logs an error and returns empty arrays' do
        expect(Rails.logger).to receive(:error).with(
          {
            message: 'Encoding issue detected - possible data corruption',
            check_in_uuid: id,
            error: 'Invalid encoding'
          }
        )

        appointments, demographics_status = service_instance.send(:parse_check_in_response_data, raw_data)

        expect(appointments).to eq([])
        expect(demographics_status).to eq({})
      end
    end

    context 'when StandardError occurs' do
      let(:raw_data) { double('FaradayResponse', body: 'some data') }

      before do
        allow(Oj).to receive(:load).and_raise(StandardError.new('Unexpected error'))
      end

      it 'logs an error and returns empty arrays' do
        expect(Rails.logger).to receive(:error).with(
          {
            message: 'Unexpected error parsing check-in response',
            check_in_uuid: id,
            error: 'Unexpected error'
          }
        )

        appointments, demographics_status = service_instance.send(:parse_check_in_response_data, raw_data)

        expect(appointments).to eq([])
        expect(demographics_status).to eq({})
      end
    end

    context 'when parsed data is missing expected keys' do
      let(:raw_data) { double('FaradayResponse', body: '{}') }

      it 'returns empty arrays for missing data' do
        appointments, demographics_status = service_instance.send(:parse_check_in_response_data, raw_data)

        expect(appointments).to eq([])
        expect(demographics_status).to eq({})
      end
    end
  end
end
