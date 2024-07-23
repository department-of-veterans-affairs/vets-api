# frozen_string_literal: true

require 'pension_21p527ez/tag_sentry'
require 'pension_21p527ez/monitor'

module V0
  class IncomeAndAssetsClaimsController < ClaimsBaseController
    service_tag 'income-and-assets-application'

    def short_name
      'income_and_assets_claim'
    end

    def claim_class
      SavedClaim::IncomeAndAssets
    end
  end
end
