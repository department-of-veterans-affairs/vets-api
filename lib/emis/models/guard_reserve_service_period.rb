# frozen_string_literal: true

module EMIS
  module Models
    class GuardReserveServicePeriod
      include Virtus.model

      attribute :segment_identifier, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :termination_reason, String
      attribute :character_of_service_code, String
      attribute :narrative_reason_for_separation_code, String
      attribute :statute_code, String
      attribute :project_code, String
      attribute :post_911_gibill_loss_category_code, String
      attribute :training_indicator_code, String
    end
  end
end
