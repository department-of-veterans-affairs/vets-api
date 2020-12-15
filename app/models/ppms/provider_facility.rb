# frozen_string_literal: true

require 'facilities/ppms/v0/client'
require 'facilities/ppms/v1/client'
require 'lighthouse/facilities/client'

class PPMS::ProviderFacility < Common::Base
  attribute :facilities, Array
  attribute :id, String
  attribute :lighthouse_params, Hash
  attribute :pagination_params, Hash
  attribute :ppms_params, Hash
  attribute :providers, Array

  def initialize(attr = {})
    super(attr)
    @id = SecureRandom.uuid

    @providers = ppms_api_results
    @facilities = lighthouse_api_results
  end

  def provider_ids
    providers.collect(&:id)
  end

  def facility_ids
    facilities.collect(&:id)
  end

  private

  def ppms_api_results
    if Flipper.enabled?(:facility_locator_ppms_use_v1_client)
      ppms_api_results_v1
    else
      ppms_api_results_v0
    end
  end

  def ppms_api_results_v0
    Facilities::PPMS::V0::Client.new.pos_locator(ppms_params.with_indifferent_access).collect do |result|
      provider = PPMS::Provider.new(
        result.attributes.transform_keys { |k| k.to_s.snakecase.to_sym }
      )
      provider.set_hexdigest_as_id!
      provider
    end.uniq(&:id).paginate(pagination_params)
  end

  def ppms_api_results_v1
    Facilities::PPMS::V1::Client.new.pos_locator(ppms_params.with_indifferent_access)
  end

  def lighthouse_api_results
    Lighthouse::Facilities::Client.new.get_facilities(
      lighthouse_params.with_indifferent_access.merge(
        type: :health,
        services: ['UrgentCare']
      )
    )
  end
end
