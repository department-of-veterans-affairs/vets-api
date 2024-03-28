# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Claims API power of attorney routing', type: :routing do
  base_path = '/services/claims/v2/'
  controller_base = 'claims_api/v2/veterans/power_of_attorney'

  it "routes #{base_path}/veterans/:veteranId/power-of-attorney to PowerOfAttorneyController#show" do
    poa_path = "#{base_path}/veterans/123/power-of-attorney"

    expect(get(poa_path)).to route_to(
      format: 'json',
      controller: "#{controller_base}/base",
      action: 'show',
      veteranId: '123'
    )
  end

  it "routes #{base_path}/veterans/:veteranId/2122/validate to PowerOfAttorneyController#validate" do
    validate2122_path = "#{base_path}/veterans/123/2122/validate"

    expect(post(validate2122_path)).to route_to(
      format: 'json',
      controller: "#{controller_base}/organization",
      action: 'validate',
      veteranId: '123'
    )
  end

  it "routes #{base_path}/veterans/:veteranId/2122 to PowerOfAttorneyController#submit" do
    submit2122_path = "#{base_path}/veterans/123/2122"

    expect(post(submit2122_path)).to route_to(
      format: 'json',
      controller: "#{controller_base}/organization",
      action: 'submit',
      veteranId: '123'
    )
  end

  it "routes #{base_path}/veterans/:veteranId/2122a/validate to PowerOfAttorneyController#validate" do
    validate2122a_path = "#{base_path}/veterans/123/2122a/validate"

    expect(post(validate2122a_path)).to route_to(
      format: 'json',
      controller: "#{controller_base}/individual",
      action: 'validate',
      veteranId: '123'
    )
  end

  it "routes #{base_path}/veterans/:veteranId/2122a to PowerOfAttorneyController#submit" do
    submit2122a_path = "#{base_path}/veterans/123/2122a"

    expect(post(submit2122a_path)).to route_to(
      format: 'json',
      controller: "#{controller_base}/individual",
      action: 'submit',
      veteranId: '123'
    )
  end

  it "routes #{base_path}/veterans/:veteranId/power-of-attorney/:id to PowerOfAttorneyController#status" do
    poa_status_path = "#{base_path}/veterans/123/power-of-attorney/456"

    expect(get(poa_status_path)).to route_to(
      format: 'json',
      controller: "#{controller_base}/base",
      action: 'status',
      veteranId: '123',
      id: '456'
    )
  end
end
