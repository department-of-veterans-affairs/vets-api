# frozen_string_literal: true

module VaForms
  module V0
    class FormsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        render json: Form.search(search_term: params[:query], show_deleted: params[:show_deleted]),
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: VaForms::FormListSerializer,
               show_deleted: params[:show_deleted]
      end

      def show
        forms = Form.find_by form_name: params[:id]
        render json: forms,
               serializer: VaForms::FormDetailSerializer
      end
    end
  end
end
