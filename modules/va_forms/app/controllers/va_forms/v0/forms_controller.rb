# frozen_string_literal: true

module VAForms
  module V0
    class FormsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        if ActiveModel::Type::Boolean.new.cast params[:enabled]
          render json: Form.new_search(params[:query]),
                 serializer: ActiveModel::Serializer::CollectionSerializer,
                 each_serializer: VAForms::FormListSerializer
        else
          render json: Form.search(params[:query]),
                 serializer: ActiveModel::Serializer::CollectionSerializer,
                 each_serializer: VAForms::FormListSerializer
        end
      end

      def show
        forms = Form.find_by form_name: params[:id]
        if forms.present?
          render json: forms,
                 serializer: VAForms::FormDetailSerializer
        else
          render json: { errors: [{ detail: 'Form not found' }] },
                 status: :not_found
        end
      end
    end
  end
end
