# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AppointmentsService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :jac) }
  let(:start_date) { Time.zone.parse('2021-06-04T04:00:00.000Z') }
  let(:end_date) { Time.zone.parse('2022-07-03T04:00:00.000Z') }
  let(:start_date2) { Time.zone.parse('2022-01-01T19:25:00Z') }
  let(:end_date2) { Time.zone.parse('2022-12-01T19:45:00Z') }
  let(:start_date3) { Time.zone.parse('2022-04-01T19:25:00Z') }
  let(:end_date3) { Time.zone.parse('2023-03-01T19:45:00Z') }
  let(:id) { '202006031600983000030800000000000000' }
  let(:appointment_id) { 123 }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#post_appointment' do
    let(:va_proposed_clinic_request_body) do
      FactoryBot.build(:appointment_form_v2, :va_proposed_clinic, user: user).attributes
    end

    let(:va_proposed_phone_request_body) do
      FactoryBot.build(:appointment_form_v2, :va_proposed_phone, user: user).attributes
    end

    let(:va_booked_request_body) do
      FactoryBot.build(:appointment_form_v2, :va_booked, user: user).attributes
    end

    let(:community_cares_request_body) do
      FactoryBot.build(:appointment_form_v2, :community_cares, user: user).attributes
    end

    context 'when va appointment create request is valid' do
      # appointment created using the Jacqueline Morgan user

      it 'returns the created appointment - va - booked' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_JACQUELINE_M',
                         match_requests_on: %i[method path query]) do
          allow(Rails.logger).to receive(:info).at_least(:once)
          response = subject.post_appointment(va_booked_request_body)
          expect(response[:id]).to be_a(String)
        end
      end

      it 'returns the created appointment and logs data' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_and_logs_data',
                         match_requests_on: %i[method path query]) do
          allow(Rails.logger).to receive(:info).at_least(:once)
          response = subject.post_appointment(va_booked_request_body)
          expect(response[:id]).to be_a(String)
          expect(Rails.logger).to have_received(:info).with('VAOS appointment service category and type',
                                                            any_args).at_least(:once)
          expect(Rails.logger).to have_received(:info).with('VAOS telehealth atlas details',
                                                            any_args).at_least(:once)
        end
      end

      it 'returns the created appointment-va-proposed-clinic' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_va_proposed_clinic_200',
                         match_requests_on: %i[method path query]) do
          response = subject.post_appointment(va_proposed_clinic_request_body)
          expect(response[:id]).to eq('70065')
        end
      end
    end

    context 'when cc appointment create request is valid' do
      it 'returns the created appointment - cc - proposed' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_cc_200_2222022',
                         match_requests_on: %i[method path query]) do
          response = subject.post_appointment(community_cares_request_body)
          expect(response[:id]).to be_a(String)
        end
      end
    end

    context 'when the patientIcn is missing' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_400', match_requests_on: %i[method path query]) do
          expect { subject.post_appointment(community_cares_request_body) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when the patientIcn is missing on a direct scheduling submission' do
      it 'raises a backend exception and logs error details' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_400', match_requests_on: %i[method path query]) do
          allow(Rails.logger).to receive(:warn).at_least(:once)
          expect { subject.post_appointment(va_booked_request_body) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
          expect(Rails.logger).to have_received(:warn).with('Direct schedule submission error',
                                                            any_args).at_least(:once)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_500', match_requests_on: %i[method path query]) do
          expect { subject.post_appointment(community_cares_request_body) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_appointments' do
    context 'when requesting a list of appointments given a date range' do
      it 'returns a 200 status with list of appointments' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200_12082022', match_requests_on: %i[method path query],
                                                                               tag: :force_utf8) do
          response = subject.get_appointments(start_date2, end_date2)
          expect(response[:data].size).to eq(395)
        end
      end

      it 'logs the service categories of the returned appointments' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200_and_log_data',
                         match_requests_on: %i[method path query], tag: :force_utf8) do
          allow(Rails.logger).to receive(:info).at_least(:once)
          response = subject.get_appointments(start_date3, end_date3)
          expect(response[:data].size).to eq(163)
          expect(Rails.logger).to have_received(:info).with('VAOS appointment service category and type',
                                                            any_args).at_least(:once)
          expect(Rails.logger).to have_received(:info).with('VAOS telehealth atlas details',
                                                            any_args).at_least(:once)
        end
      end
    end

    context 'when requesting a list of appointments given a date range and single status' do
      it 'returns a 200 status with list of appointments' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_single_status_200',
                         match_requests_on: %i[method path query], tag: :force_utf8) do
          response = subject.get_appointments(start_date2, end_date2, 'proposed')
          expect(response[:data].size).to eq(4)
          expect(response[:data][0][:status]).to eq('proposed')
        end
      end
    end

    context 'when requesting a list of appointments given a date range and multiple statuses' do
      it 'returns a 200 status with list of appointments' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_multi_status_200',
                         match_requests_on: %i[method path query], tag: :force_utf8) do
          response = subject.get_appointments(start_date2, end_date2, 'proposed,booked')
          expect(response[:data].size).to eq(4)
          expect(response[:data][0][:status]).to eq('proposed')
          expect(response[:data][1][:status]).to eq('booked')
        end
      end
    end

    context '400' do
      it 'raises a 400 error' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_400', match_requests_on: %i[method path query]) do
          expect { subject.get_appointments(start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context '401' do
      it 'raises a 401 error' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_401', match_requests_on: %i[method path query]) do
          expect { subject.get_appointments(start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context '403' do
      it 'raises a 403' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_403', match_requests_on: %i[method path query]) do
          expect { subject.get_appointments(start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_500', match_requests_on: %i[method path query]) do
          expect { subject.get_appointments(start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_appointment' do
    context 'with an appointment' do
      context 'with Jacqueline Morgan' do
        # it 'returns a proposed appointment' do
        #   VCR.use_cassette('vaos/v2/appointments/get_appointment_200_JUDY_BOOKED', record: :new_episodes) do
        #     response = subject.get_appointment('71079')
        #     expect(response[:id]).to eq('70060')
        #     expect(response[:kind]).to eq('clinic')
        #     expect(response[:status]).to eq('proposed')
        #   end
        # end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/get_appointment_500', match_requests_on: %i[method path query]) do
          expect { subject.get_appointment('00000') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#cancel_appointment' do
    context 'when the upstream server attemps to cancel an appointment' do
      context 'with Jaqueline Morgan' do
        it 'returns a cancelled status and the cancelled appointment information' do
          VCR.use_cassette('vaos/v2/appointments/cancel_appointments_200', match_requests_on: %i[method path query]) do
            response = subject.update_appointment('70060', 'cancelled')
            expect(response.status).to eq('cancelled')
          end
        end
      end

      it 'returns a 400 when the appointment is not cancellable' do
        VCR.use_cassette('vaos/v2/appointments/cancel_appointment_400', match_requests_on: %i[method path query]) do
          expect { subject.update_appointment('42081', 'cancelled') }
            .to raise_error do |error|
            expect(error).to be_a(Common::Exceptions::BackendServiceException)
            expect(error.status_code).to eq(400)
          end
        end
      end
    end

    context 'when there is a server error in updating an appointment' do
      it 'throws a BackendServiceException' do
        VCR.use_cassette('vaos/v2/appointments/cancel_appointment_500', match_requests_on: %i[method path query]) do
          expect { subject.update_appointment('35952', 'cancelled') }
            .to raise_error do |error|
            expect(error).to be_a(Common::Exceptions::BackendServiceException)
            expect(error.status_code).to eq(502)
          end
        end
      end
    end
  end
end
