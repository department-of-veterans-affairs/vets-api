# frozen_string_literal: true

module EMIS
  module Models
    class VeteranStatus
      include Virtus.model

      attribute :title38_status_code, String
      attribute :post911_deployment_indicator, String
      attribute :post911_combat_indicator, String
      attribute :pre911_deployment_indicator, String
    end
  end
end
