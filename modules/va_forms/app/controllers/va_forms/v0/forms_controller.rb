# frozen_string_literal: true

module VAForms
  module V0
    class FormsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        if Flipper.enabled?(:new_va_forms_search)
          if params[:query].present?
            # The regex below checks to see if a form follows the DD-DDDD format (with optional alpha characters)
            va_prefix_regex = /^\d{2}(?:[pP])?[- \s]\d+(?:[a-zA-Z])?$/
            sf_form_regex = /^[sS][fF](?:[- \s])?\d+(?:[a-zA-Z])?$/
            if params[:query].match(va_prefix_regex).present? || params[:query].match(sf_form_regex).present?
              return search_by_form_number
            end

            return search_by_text
          end
          return_all
        else
          old_search
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

      def old_search
        render json: Form.old_search(search_term: params[:query]),
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
