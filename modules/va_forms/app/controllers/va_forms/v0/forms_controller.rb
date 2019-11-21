# frozen_string_literal: true

module VaForms
  module V0
    class FormsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        render json: get_forms,
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: VaForms::FormListSerializer
      end

      def show
        forms = Form.find_by form_name: params[:id]
        render json: forms,
               serializer: VaForms::FormDetailSerializer
      end

      private

      def get_forms
        if params[:form_number].present? || params[:keyword].present?
          result = Form
          result = result.where('name like ?', "%#{params[:form_number]}%") if params[:form_number].present?
          result = result.where('title like ?', "%#{params[:keyword]}%") if params[:keyword].present?
          result
        else
          Form.all
        end
      end
    end
  end
end
