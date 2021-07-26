# frozen_string_literal: true

require 'va_forms/regex_helper'

module VAForms
  module V0
    class FormsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        if params[:query].present?
          # Checks to see if a form follows the SF/VA DD(p)-DDDD format
          params[:query].strip!
          valid_search_regex = /^\d{2}[pP]?-\d+(?:-)?[a-zA-Z]{0,2}(?:-.)?$/
          return search_by_form_number if params[:query].match(valid_search_regex).present?

          return search_by_text(VAForms::RegexHelper.new.scrub_query(params[:query]))
        end
        return_all
      end

      def search_by_form_number
        render json: Form.search_by_form_number(params[:query]),
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: VAForms::FormListSerializer
      end

      def search_by_text(query)
        render json: Form.search(query),
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
