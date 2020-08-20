# frozen_string_literal: true

module VaForms
  module V0
    class FormsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        render json: Form.search(search_term: params[:query]),
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: VaForms::FormListSerializer
      end

      def show
        forms = Form.find_by form_name: params[:id]
        render json: forms,
               serializer: VaForms::FormDetailSerializer
      end
    end
  end
end
