# frozen_string_literal: true

module MyHealth
  module V1
    class ConditionsController < MRController
      def index
        render_resource client.list_conditions
      end

      def show
        condition_id = params[:id].try(:to_i)
        render_resource client.get_condition(condition_id)
      end
    end
  end
end
