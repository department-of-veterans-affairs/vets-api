# frozen_string_literal: true

require 'rails_helper'

describe VAOS::Middleware::VaosLogging do
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
      xit 'increments statsd and logs additional details in a success line' do
        VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[method uri]) do
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.external_http_request.VAOS.success:1 '\
'#endpoint:/appointments/v1/patients/xxx/appointments #method:get'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] measure api.external_http_request.VAOS.time:0.0 '\
'#endpoint:/appointments/v1/patients/xxx/appointments #method:get'
          )
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment shared.sidekiq.default.VAOS_ExtendSessionJob.enqueue:1'
          )
          expect(Rails.logger).to receive(:info).with('[StatsD] increment api.vaos.get_appointments.total:1')
          expect(Rails.logger).to receive(:info).with('VAOS service call succeeded!',
                                                      duration: 0.0,
                                                      jti: 'unknown jti',
                                                      status: 200,
                                                      url: '(GET) https://veteran.apps.va.gov/appointments'\
'/v1/patients/1012845331V153043/appointments?endDate=2020-07-02T08%3A00%3A00Z&pageSize=0&startDate='\
'2020-06-02T07%3A00%3A00Z&useCache=false')
          service.get_appointments(type, start_date, end_date)
        end
      end
    end

    context 'with a failed response' do
      it 'increments statsd and logs additional details in a failure line' do
        VCR.use_cassette('vaos/appointments/get_appointments_500', match_requests_on: %i[method uri]) do
          expect(Rails.logger).to receive(:info).with('[StatsD] increment api.vaos.get_appointments.total:1')
          expect(Rails.logger).to receive(:info).with(
            '[StatsD] increment api.vaos.get_appointments.fail:1 '\
              '#error:VAOS::ServiceException'
          )
          expect(Rails.logger).to receive(:warn).with('VAOS service call failed!',
                                                      duration: 0.0,
                                                      jti: 'unknown jti',
                                                      status: 500,
                                                      url: '(GET) https://veteran.apps.va.gov/appointments/v1'\
'/patients/1012845331V153043/appointments?endDate=2020-07-02T08%3A00%3A00Z&pageSize=0&startDate='\
'2020-06-02T07%3A00%3A00Z&useCache=false')
          expect { service.get_appointments(type, start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
