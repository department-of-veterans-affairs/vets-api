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
    response = @service.get_data(path: 'intake-sites')
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
    DisabilityCompensation::ApiProvider::IntakeSitesResponse.new(separation_locations:)
  end
end
