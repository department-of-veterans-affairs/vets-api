# frozen_string_literal: true

require 'disability_compensation/providers/brd/brd_provider'
require 'disability_compensation/responses/intake_sites_response'
require 'lighthouse/benefits_reference_data/service'

class LighthouseBRDProvider
  include BRDProvider

  def initialize(_current_user)
    @service = BenefitsReferenceData::Service.new
  end

  def get_separation_locations
    api_key = nil
    settings = nil
    # Flipper.enable(:disability_compensation_staging_lighthouse_brd_key)
    # Flipper.disable(:disability_compensation_staging_lighthouse_brd_key)
    if Flipper.enabled?(:disability_compensation_staging_lighthouse_brd_key)
      api_key =  Settings.lighthouse.staging_api_key
      settings = OpenStruct.new({
                                  url: Settings.lighthouse.benefits_reference_data.staging_url,
                                  path: Settings.lighthouse.benefits_reference_data.path,
                                  version: 'v1',
                                })
    end

    response = @service.get_data(path: 'intake-sites', options: {api_key:, settings:})
    if response.status != 200
      return DisabilityCompensation::ApiProvider::IntakeSitesResponse.new(status: response.status)
    end

    transform(response.body)
  end

  private

  def transform(data)
    separation_locations = data['items'].map do |intake_site|
      DisabilityCompensation::ApiProvider::SeparationLocation.new(
        code: intake_site['id'],
        description: intake_site['description']
      )
    end

    DisabilityCompensation::ApiProvider::IntakeSitesResponse.new(separation_locations:, status: 200)
  end
end
