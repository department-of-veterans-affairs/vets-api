# frozen_string_literal: true

require 'will_paginate/array'
class V1::Facilities::VaCcpController < FacilitiesController
  def urgent_care
    ppms_api_results = ppms_api.pos_locator(ppms_params).collect do |result|
      PPMS::Provider.new(
        result.attributes.transform_keys { |k| k.to_s.snakecase.to_sym }
      )
    end.uniq(&:id).paginate(pagination_params)

    lighthouse_api_results = lighthouse_api.get_facilities(
      lighthouse_params.merge(
        type: :health,
        services: ['UrgentCare']
      )
    )

    providers_facilities = PPMS::ProviderFacility.new
    providers_facilities.providers = ppms_api_results
    providers_facilities.facilities = lighthouse_api_results

    render_json(
      PPMS::ProviderFacilitySerializer,
      ppms_params,
      [providers_facilities],
      { include: %i[providers facilities] }
    )
  end

  private

  def ppms_api
    Facilities::PPMS::Client.new
  end

  def lighthouse_api
    Lighthouse::Facilities::Client.new
  end

  def pagination_params
    hsh = super
    page = Integer(hsh[:page] || 1)
    per_page = Integer(hsh[:per_page] || 1)
    total_entries = page * per_page + 1
    hsh.compact.transform_values!(&:to_i)
    hsh.merge(
      total_entries: total_entries
    )
  end

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
