# frozen_string_literal: true

require 'rails_helper'

describe VAOS::AppointmentService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos) }
  let(:start_date) { Time.zone.parse('2020-06-02T07:00:00Z') }
  let(:end_date) { Time.zone.parse('2020-07-02T08:00:00Z') }
  let(:id) { '202006031600983000030800000000000000' }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#post_appointment' do
    context 'when request is mal-formed' do
      let(:request_body) do
        FactoryBot.build(:appointment_form, :ineligible).attributes
      end

      it 'returns a 400 Bad Request' do
        VCR.use_cassette('vaos/appointments/post_appointment_400', match_requests_on: %i[method uri]) do
          allow(Rails.logger).to receive(:warn).at_least(:once)
          expect { subject.post_appointment(request_body) }
            .to raise_error(Common::Exceptions::BackendServiceException) do |error|
              expect(error.status_code).to eq(400)
            end
          expect(Rails.logger).to have_received(:warn).with('Direct schedule submission error',
                                                            any_args).at_least(:once)
        end
      end
    end

    context 'when request is in conflict' do
      let(:request_body) do
        FactoryBot.build(:appointment_form, :ineligible).attributes
      end

      it 'returns a 400 Bad Request for 409 conlicts as well' do
        VCR.use_cassette('vaos/appointments/post_appointment_409', match_requests_on: %i[method uri]) do
          allow(Rails.logger).to receive(:warn).at_least(:once)
          expect { subject.post_appointment(request_body) }
            .to raise_error(Common::Exceptions::BackendServiceException) do |error|
              expect(error.status_code).to eq(409)
            end
          expect(Rails.logger).to have_received(:warn).with('Direct schedule submission error',
                                                            any_args).at_least(:once)
        end
      end
    end

    context 'when request is valid' do
      let(:request_body) do
        FactoryBot.build(:appointment_form, :eligible).attributes
      end

      it 'returns the created appointment' do
        VCR.use_cassette('vaos/appointments/post_appointment', match_requests_on: %i[method uri]) do
          response = subject.post_appointment(request_body)
          expect(response).to be_a(Hash)
        end
      end
    end
  end

  describe '#put_cancel_appointment' do
    context 'when appointment cannot be cancelled' do
      let(:request_body) do
        {
          appointment_time: '11/15/19 20:00:00',
          clinic_id: '408',
          facility_id: '983',
          cancel_reason: 'whatever',
          cancel_code: '5',
          remarks: nil,
          clinic_name: nil
        }
      end

      it 'returns the bad request with detail in errors' do
        VCR.use_cassette('vaos/appointments/put_cancel_appointment_409', match_requests_on: %i[method uri]) do
          expect { subject.put_cancel_appointment(request_body) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when appointment can be cancelled' do
      let(:request_body) do
        {
          appointment_time: '11/15/2019 13:00:00',
          clinic_id: '437',
          facility_id: '983',
          cancel_reason: '5',
          cancel_code: 'PC',
          remarks: '',
          clinic_name: 'CHY OPT VAR1'
        }
      end

      it 'cancels the appointment' do
        VCR.use_cassette('vaos/appointments/put_cancel_appointment', match_requests_on: %i[method uri]) do
          response = subject.put_cancel_appointment(request_body)
          expect(response).to be_an_instance_of(String).and be_empty
        end
      end
    end
  end

  describe '#get_appointments of type va' do
    let(:type) { 'va' }

    context 'when appointments return a 200 with a partial error' do
      around do |example|
        Settings.sentry.dsn = true
        example.run
        Settings.sentry.dsn = nil
      end

      it 'logs those partial responses to sentry' do
        VCR.use_cassette('vaos/appointments/get_appointments_200_partial_error', match_requests_on: %i[method uri]) do
          expect(Raven).to receive(:capture_message).with(
            'VAOS::AppointmentService#get_appointments has response errors.',
            level: 'info'
          )
          expect(Raven).to receive(:extra_context).with(
            errors: '[{"code":1,"source":"test result","summary":"test summary"}]'
          )
          subject.get_appointments(type, start_date, end_date)
        end
      end
    end

    context 'with 12 va appointments' do
      it 'returns an array of size 12' do
        VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[method uri], tag: :force_utf8) do
          response = subject.get_appointments(type, start_date, end_date)
          expect(response[:data].size).to eq(28)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/appointments/get_appointments_500', match_requests_on: %i[method uri]) do
          expect { subject.get_appointments(type, start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_appointments of type cc' do
    let(:type) { 'cc' }

    context 'with 17 cc appointments' do
      it 'returns an array of size 17' do
        VCR.use_cassette('vaos/appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
          response = subject.get_appointments(type, start_date, end_date)
          expect(response[:data].size).to eq(101)
        end
      end
    end

    context 'with 0 cc appointments' do
      it 'returns an array of size 0' do
        VCR.use_cassette('vaos/appointments/get_cc_appointments_empty', match_requests_on: %i[method uri]) do
          response = subject.get_appointments(type, start_date, end_date)
          expect(response[:data].size).to eq(0)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/appointments/get_cc_appointments_500', match_requests_on: %i[method uri]) do
          expect { subject.get_appointments(type, start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#show_appointment of type va' do
    context 'returns single appointment' do
      let(:id) { '202006031600983000030800000000000000.aaaaaa' }

      it 'with a 200 success' do
        VCR.use_cassette('vaos/appointments/show_appointment', match_requests_on: %i[method uri]) do
          response = subject.get_appointment(id)
          expect(response[:id]).to eq(id)
        end
      end
    end

    context 'when upstream service returns an empty string in body' do
      it 'returns nil in body' do
        VCR.use_cassette('vaos/appointments/show_appointment', match_requests_on: %i[method uri]) do
          response = subject.get_appointment('123456789101112')
          expect(response.body).to be_nil
        end
      end
    end

    context 'returns single appointment with dash in app id' do
      let(:id) { '202006031600983000030800000000000000-aaaaaa' }

      it 'with a 200 success' do
        VCR.use_cassette('vaos/appointments/show_appointment_with_dash', match_requests_on: %i[method uri]) do
          response = subject.get_appointment(id)
          expect(response[:id]).to eq(id)
        end
      end
    end

    context 'returns error status' do
      it 'with a 404 not found' do
        VCR.use_cassette('vaos/appointments/show_appointment_404', match_requests_on: %i[method uri]) do
          expect { subject.get_appointment('1234567') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      it 'with a 500 internal server error' do
        VCR.use_cassette('vaos/appointments/show_appointment_500', match_requests_on: %i[method uri]) do
          expect { subject.get_appointment('1234567') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
