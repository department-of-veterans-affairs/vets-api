# frozen_string_literal: true

class V0::BgsController < ApplicationController
  skip_before_action :authenticate

  def find_poa_for_claim
    service = BGS::Services.new(
      env: 'Webtest',
      client_ip: '172.30.2.135',
      client_station_id: '281',
      client_username: 'VAgovAPI',
      external_uid: 'test',
      external_key: 'test',
      application: 'VAgovAPI',
      log: true,
      forward_proxy_url: 'https://internal-dsva-vagov-dev-fwdproxy-1893365470.us-gov-west-1.elb.amazonaws.com:4447'
    )
    service.org.find_poas_by_claim_id(params[:id])
  end
end
