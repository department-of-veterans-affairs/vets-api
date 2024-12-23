# frozen_string_literal: true

require 'disability_compensation/providers/brd/lighthouse_brd_provider'
require 'lighthouse/benefits_reference_data_staging/service'

class LighthouseStagingBRDProvider < LighthouseBRDProvider
  def initialize(_current_user)
    super
    @service = BenefitsReferenceData::Staging::Service.new
  end
end
