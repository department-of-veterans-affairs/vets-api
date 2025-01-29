# frozen_string_literal: true

module Rswag
  class TextHelpers
    def claims_api_docs
      "modules/claims_api/app/swagger/claims_api/v2/#{project_environment}swagger.json"
    end

    private

    def project_environment
      environment? ? "#{ENV.fetch('DOCUMENTATION_ENVIRONMENT', nil)}/" : nil
    end

    def environment?
      ENV['DOCUMENTATION_ENVIRONMENT'].present?
    end
  end
end
