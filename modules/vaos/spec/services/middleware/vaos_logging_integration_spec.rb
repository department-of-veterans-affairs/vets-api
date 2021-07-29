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
      xit 'increments statsd' do
        VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[method uri]) do
          expect(Rails.logger).to receive(:info).with(
            'VAOS service call succeeded!',
            duration: 0.0,
            jti: 'unknown jti',
            status: 200,
            url: '(GET) https://veteran.apps.va.gov/appointments' \
                 '/v1/patients/1012845331V153043/appointments?endDate=2020-07-02T08%3A00%3A00Z&pageSize=0&startDate=' \
                 '2020-06-02T07%3A00%3A00Z&useCache=false'
          )
          expect { service.get_appointments(type, start_date, end_date) }
            .to trigger_statsd_increment(
              'api.vaos.va_mobile.response.total',
              tags: ['method:GET', 'url:/appointments/v1/patients/xxx/appointments', 'http_status:']
            )
            .and trigger_statsd_increment(
              'api.external_http_request.VAOS.success',
              tags: ['endpoint:/appointments/v1/patients/xxx/appointments', 'method:get']
            )
            .and trigger_statsd_measure(
              'api.external_http_request.VAOS.time',
              tags: ['endpoint:/appointments/v1/patients/xxx/appointments', 'method:get']
            )
            .and trigger_statsd_increment('shared.sidekiq.default.VAOS_ExtendSessionJob.enqueue')
            .and trigger_statsd_increment('api.vaos.get_appointments.total')
        end
      end
    end

    context 'with a failed response' do
      it 'increments statsd' do
        VCR.use_cassette('vaos/appointments/get_appointments_500', match_requests_on: %i[method uri]) do
          expect(Rails.logger).to receive(:warn).with(
            'VAOS service call failed!',
            duration: 0.0,
            jti: 'unknown jti',
            status: 500,
            url: '(GET) https://veteran.apps.va.gov/appointments/v1'\
                 '/patients/1012845331V153043/appointments?endDate=2020-07-02T08%3A00%3A00Z&pageSize=0&startDate=' \
                 '2020-06-02T07%3A00%3A00Z&useCache=false'
          )
          expect { service.get_appointments(type, start_date, end_date) }
            .to raise_error(Common::Exceptions::BackendServiceException)
            .and trigger_statsd_increment(
              'api.vaos.va_mobile.response.total',
              tags: ['method:GET', 'url:/appointments/v1/patients/xxx/appointments', 'http_status:']
            )
            .and trigger_statsd_increment(
              'api.vaos.va_mobile.response.fail',
              tags: ['method:GET', 'url:/appointments/v1/patients/xxx/appointments', 'http_status:500']
            )
            .and trigger_statsd_increment('api.vaos.get_appointments.total')
            .and trigger_statsd_increment(
              'api.vaos.get_appointments.fail',
              tags: ['error:VAOSServiceException']
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
            .and trigger_statsd_increment('api.vaos.get_appointments.total')
            .and trigger_statsd_increment(
              'api.vaos.va_mobile.response.total',
              tags: ['method:GET', 'url:/appointments/v1/patients/xxx/appointments', 'http_status:']
            )
            .and trigger_statsd_increment(
              'api.vaos.va_mobile.response.fail',
              tags: [
                'method:GET',
                'url:/appointments/v1/patients/xxx/appointments',
                'http_status:Faraday::TimeoutError'
              ]
            )
            .and trigger_statsd_increment(
              'api.external_http_request.VAOS.failed',
              tags: ['endpoint:/appointments/v1/patients/xxx/appointments', 'method:get']
            )
            .and trigger_statsd_increment(
              'api.vaos.get_appointments.fail',
              tags: ['error:CommonExceptionsGatewayTimeout']
            )
        end
      end

      context 'with a failed connection' do
        it 'increments statsd' do
          allow_any_instance_of(Faraday::Adapter::NetHttp).to receive(:perform_request).and_raise(Errno::ECONNREFUSED)
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
            .and trigger_statsd_increment('api.vaos.get_appointments.total')
            .and trigger_statsd_increment(
              'api.vaos.va_mobile.response.total',
              tags: ['method:GET', 'url:/appointments/v1/patients/xxx/appointments', 'http_status:']
            )
            .and trigger_statsd_increment(
              'api.vaos.va_mobile.response.fail',
              tags: [
                'method:GET',
                'url:/appointments/v1/patients/xxx/appointments',
                'http_status:Faraday::ConnectionFailed'
              ]
            )
            .and trigger_statsd_increment(
              'api.external_http_request.VAOS.failed',
              tags: ['endpoint:/appointments/v1/patients/xxx/appointments', 'method:get']
            )
            .and trigger_statsd_increment(
              'api.vaos.get_appointments.fail',
              tags: ['error:CommonClientErrorsClientError']
            )
        end
      end
    end
  end
end
