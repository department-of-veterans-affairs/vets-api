# frozen_string_literal: true

unless Rails.env.test?

  Rails.application.reloader.to_prepare do
    # duration/success/fail of GET, POST calls for controllers
    CheckIn::V2::SessionsController.extend(StatsD::Instrument)
    CheckIn::V2::PatientCheckInsController.extend(StatsD::Instrument)
    CheckIn::V2::PreCheckInsController.extend(StatsD::Instrument)
    %i[show create].each do |method|
      CheckIn::V2::SessionsController.statsd_measure method, lambda { |object, _args|
        "api.#{check_in_type(object.params)}.v2.sessions.#{method}.measure"
      }
      CheckIn::V2::SessionsController.statsd_count_success method, lambda { |object, _args|
        "api.#{check_in_type(object.params)}.v2.sessions.#{method}.count"
      }
      CheckIn::V2::PatientCheckInsController.statsd_measure method, "api.check_in.v2.checkins.#{method}.measure"
      CheckIn::V2::PatientCheckInsController.statsd_count_success method, "api.check_in.v2.checkins.#{method}.count"
      CheckIn::V2::PreCheckInsController.statsd_measure method, "api.check_in.v2.pre_checkins.#{method}.measure"
      CheckIn::V2::PreCheckInsController.statsd_count_success method, "api.check_in.v2.pre_checkins.#{method}.count"
    end

    # Measure the count/duration of GET/POST calls for LoROTA/CHIP services
    V2::Lorota::Client.extend(StatsD::Instrument)
    %i[token data].each do |method|
      V2::Lorota::Client.statsd_count_success method, "api.check_in.v2.lorota.#{method}.count"
      V2::Lorota::Client.statsd_measure method, "api.check_in.v2.lorota.#{method}.measure"
    end

    V2::Chip::Client.extend(StatsD::Instrument)
    %i[check_in_appointment refresh_appointments pre_check_in token].each do |method|
      V2::Chip::Client.statsd_count_success method, "api.check_in.v2.chip.#{method}.count"
      V2::Chip::Client.statsd_measure method, "api.check_in.v2.chip.#{method}.measure"
    end
  end

  private

  def check_in_type(params)
    check_in_param = params[:checkInType]
    check_in_param = params.dig(:session, :check_in_type) if check_in_param.nil?
    check_in_param == 'preCheckIn' ? 'pre_check_in' : 'check_in'
  end
end
