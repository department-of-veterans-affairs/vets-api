# frozen_string_literal: true

require 'rails_helper'

describe VAOS::Middleware::VAOSLogging do
  let(:user) { build(:user, :vaos) }
  let(:service) { VAOS::AppointmentService.new(user) }
  let(:start_date) { Time.zone.parse('2020-06-02T07:00:00Z') }
  let(:end_date) { Time.zone.parse('2020-07-02T08:00:00Z') }

  before do
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    Timecop.freeze
  end

  after { Timecop.return }

  describe 'vaos logging' do
    let(:type) { 'va' }

    context 'with a succesful response' do
      # Line 38 fails Jenkins but would fail locally if removed.
      xit 'increments statsd and logs additional details in a success line' do
        VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[method uri]) do
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.va_mobile.response.total:1 #method:GET ' \
            '#url:/appointments/v1/patients/xxx/appointments #http_status:'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.external_http_request.VAOS.success:1 ' \
            '#endpoint:/appointments/v1/patients/xxx/appointments #method:get'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] measure api.external_http_request.VAOS.time:0.0 ' \
            '#endpoint:/appointments/v1/patients/xxx/appointments #method:get'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment shared.sidekiq.default.VAOS_ExtendSessionJob.enqueue:1'
          )
          expect(Rails.logger).to receive(:info).with('[StatsD] increment api.vaos.get_appointments.total:1')
          expect(Rails.logger).to receive(:info).with(
            'VAOS service call succeeded!',
            duration: 0.0,
            jti: 'unknown jti',
            status: 200,
            url: '(GET) https://veteran.apps.va.gov/appointments' \
                 '/v1/patients/1012845331V153043/appointments?endDate=2020-07-02T08%3A00%3A00Z&pageSize=0&startDate=' \
                 '2020-06-02T07%3A00%3A00Z&useCache=false'
          )
          service.get_appointments(type, start_date, end_date)
        end
      end
    end

    context 'with a failed response' do
      it 'increments statsd and logs additional details in a failure line' do
        VCR.use_cassette('vaos/appointments/get_appointments_500', match_requests_on: %i[method uri]) do
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.va_mobile.response.total:1 #method:GET ' \
            '#url:/appointments/v1/patients/xxx/appointments #http_status:'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.va_mobile.response.fail:1 #method:GET ' \
            '#url:/appointments/v1/patients/xxx/appointments #http_status:500'
          )
          expect(Rails.logger).to receive(:info).with('[StatsD] increment api.vaos.get_appointments.total:1')
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.get_appointments.fail:1 ' \
            '#error:VAOSServiceException'
          )
          expect(Rails.logger).to receive(:warn).with(
            'VAOS service call failed!',
            duration: 0.0,
            jti: 'unknown jti',
            status: 500,
            url: '(GET) https://veteran.apps.va.gov/appointments/v1'\
                 '/patients/1012845331V153043/appointments?endDate=2020-07-02T08%3A00%3A00Z&pageSize=0&startDate=' \
                 '2020-06-02T07%3A00%3A00Z&useCache=false'
          )
          expect { service.get_appointments(type, start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    describe 'with web socket error' do
      # These requests won't actually make an outbound request, because we are stubbing the Faraday adapter to
      # to raise an error that it would receive in the event of a network socket error.
      around do |example|
        VCR.turn_off!
        WebMock.allow_net_connect!
        example.run
        VCR.turn_on!
        WebMock.disable_net_connect!
      end

      context 'with a timeout' do
        it 'increments statsd and logs additional details' do
          allow_any_instance_of(Faraday::Adapter::NetHttp).to receive(:perform_request).and_raise(Timeout::Error)
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.get_appointments.total:1'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.va_mobile.response.total:1 #method:GET #url:/appointments/v1/patients/xxx/' \
            'appointments #http_status:'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.va_mobile.response.fail:1 #method:GET #url:/appointments/v1/patients/xxx/' \
            'appointments #http_status:Faraday::TimeoutError'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.external_http_request.VAOS.failed:1 #endpoint:/appointments/v1/patients/xxx/' \
            'appointments #method:get'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.get_appointments.fail:1 #error:CommonExceptionsGatewayTimeout'
          )

          expect(Rails.logger).to receive(:warn).with(
            'VAOS service call failed - Timeout::Error',
            duration: 0.0,
            jti: 'unknown jti',
            status: nil,
            url: '(GET) https://veteran.apps.va.gov/appointments' \
                 '/v1/patients/1012845331V153043/appointments?endDate=2020-07-02T08%3A00%3A00Z&pageSize=0&startDate=' \
                 '2020-06-02T07%3A00%3A00Z&useCache=false'
          ).once
          expect(Rails.logger).to receive(:warn).with(
            msg: 'Breakers failed request',
            service: 'VAOS',
            url: 'https://veteran.apps.va.gov/appointments' \
                 '/v1/patients/1012845331V153043/appointments?endDate=2020-07-02T08%3A00%3A00Z&pageSize=0&startDate=' \
                 '2020-06-02T07%3A00%3A00Z&useCache=false',
            error: 'Faraday::TimeoutError - Timeout::Error'
          ).once
          expect { service.get_appointments(type, start_date, end_date) }
            .to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end

      context 'with a failed connection' do
        it 'increments statsd and logs additional details' do
          allow_any_instance_of(Faraday::Adapter::NetHttp).to receive(:perform_request).and_raise(Errno::ECONNREFUSED)
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.get_appointments.total:1'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.va_mobile.response.total:1 #method:GET #url:/appointments/v1/patients/xxx/' \
            'appointments #http_status:'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.va_mobile.response.fail:1 #method:GET #url:/appointments/v1/patients/xxx/' \
            'appointments #http_status:Faraday::ConnectionFailed'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.external_http_request.VAOS.failed:1 #endpoint:/appointments/v1/patients/xxx/' \
            'appointments #method:get'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.get_appointments.fail:1 #error:CommonClientErrorsClientError'
          )

          expect(Rails.logger).to receive(:warn).with(
            'VAOS service call failed - Connection refused',
            duration: 0.0,
            jti: 'unknown jti',
            status: nil,
            url: '(GET) https://veteran.apps.va.gov/appointments' \
                 '/v1/patients/1012845331V153043/appointments?endDate=2020-07-02T08%3A00%3A00Z&pageSize=0&startDate=' \
                 '2020-06-02T07%3A00%3A00Z&useCache=false'
          ).once
          expect(Rails.logger).to receive(:warn).with(
            msg: 'Breakers failed request',
            service: 'VAOS',
            url: 'https://veteran.apps.va.gov/appointments'\
                 '/v1/patients/1012845331V153043/appointments?endDate=2020-07-02T08%3A00%3A00Z&pageSize=0&startDate=' \
                 '2020-06-02T07%3A00%3A00Z&useCache=false',
            error: 'Faraday::ConnectionFailed - Connection refused'
          ).once
          expect { service.get_appointments(type, start_date, end_date) }
            .to raise_error(Common::Client::Errors::ClientError)
        end
      end
    end
  end
end
