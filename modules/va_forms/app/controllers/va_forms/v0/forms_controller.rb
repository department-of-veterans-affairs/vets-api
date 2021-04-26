# frozen_string_literal: true

module VAForms
  module V0
    class FormsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        if params[:query].present?
          if params[:query].match(/^\d{2}(?:[pP])?[- \s]\d+(?:[a-zA-Z])?$/)
                           .present? || params[:query]
             .match(/^[sS][fF](?:[- \s])?\d+(?:[a-zA-Z])?$/)
             .present?
            search_by_form_number
          else
            search_by_text
          end
        else
          return_all
        end
      end

      def search_by_form_number
        render json: Form.search_by_form_number(params[:query]),
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: VAForms::FormListSerializer
      end

      def search_by_text
        render json: Form.search(params[:query]),
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: VAForms::FormListSerializer
      end

      def return_all
        render json: Form.return_all,
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: VAForms::FormListSerializer
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
