# frozen_string_literal: true

class V0::BgsController < ApplicationController
  skip_before_action :authenticate

  def index
    service = BGS::Services.new(
      env: 'webtest',
      client_ip: '172.30.2.135',
      client_station_id: '281',
      client_username: 'VAgovAPI',
      application: 'VAgovAPI',
      log: true,
      forward_proxy_url: 'https://internal-dsva-vagov-dev-fwdproxy-1893365470.us-gov-west-1.elb.amazonaws.com:4447'
    )
    Rails.logger.info '-----------'
    Rails.logger.info service.inspect
    Rails.logger.info '-----------'
    service.org.find_poas_by_claim_id('600118851')
  end
end
