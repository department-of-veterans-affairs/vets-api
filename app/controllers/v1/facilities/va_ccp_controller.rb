# frozen_string_literal: true

require 'will_paginate/array'
class V1::Facilities::VACcpController < FacilitiesController
  def urgent_care
    providers_facilities = PPMS::ProviderFacility.new(
      pagination_params: pagination_params,
      ppms_params: ppms_params,
      lighthouse_params: lighthouse_params
    )

    render_json(
      PPMS::ProviderFacilitySerializer,
      ppms_params,
      [providers_facilities],
      { include: %i[providers facilities] }
    )
  end

  private

  def ppms_params
    params.permit(
      :address,
      :page,
      :per_page,
      bbox: []
    )
  end

  def lighthouse_params
    params.permit(
      :page,
      :per_page,
      bbox: []
    )
  end

  def resource_path(options)
    urgent_care_v1_facilities_va_ccp_index(options)
  end
end
