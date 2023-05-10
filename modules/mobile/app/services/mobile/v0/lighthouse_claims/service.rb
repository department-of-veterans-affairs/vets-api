# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/service_exception'
require 'lighthouse/benefits_claims/service'

module Mobile
  module V0
    module LighthouseClaims
      class Service < BenefitsClaims::Service
        configuration Mobile::V0::LighthouseClaims::Configuration
      end
    end
  end
end
