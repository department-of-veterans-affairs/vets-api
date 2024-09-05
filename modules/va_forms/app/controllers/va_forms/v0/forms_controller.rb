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
        forms = Form.search_by_form_number(params[:query])
        render json: VAForms::FormListSerializer.new(forms)
      end

      def search_by_text(query)
        forms = Form.search(query)
        render json: VAForms::FormListSerializer.new(forms)
      end

      def return_all
        forms = Form.return_all
        render json: VAForms::FormListSerializer.new(forms)
      end

      def show
        forms = Form.find_by form_name: params[:id]
        if forms.present?
          render json: VAForms::FormDetailSerializer.new(forms)
        else
          render json: { errors: [{ detail: 'Form not found' }] }, status: :not_found
        end
      end
    end
  end
end
