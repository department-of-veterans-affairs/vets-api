# frozen_string_literal: true

module V0
  class Form1095BsController < ApplicationController
    before_action { authorize :form1095, :access? }
    before_action :set_form, only: %i[download_pdf download_txt]
    before_action :set_available_forms, only: :available_forms

    def available_forms
      # we are currently restricting access to only the most recent tax year
      last_year = Date.current.year - 1
      last_years_tax_form = @available_forms.select { |form| form.tax_year == last_year }.map do |form|
        { year: form.tax_year, last_updated: form.updated_at }
      end
      render json: { available_forms: last_years_tax_form }
    end

    def download_pdf
      file_name = "1095B_#{download_params[:tax_year]}.pdf"
      send_data @form.pdf_file, filename: file_name, type: 'application/pdf', disposition: 'inline'
    end

    def download_txt
      file_name = "1095B_#{download_params[:tax_year]}.txt"
      send_data @form.txt_file, filename: file_name, type: 'text/plain', disposition: 'inline'
    end

    private

    def set_form
      @form = Form1095B.find_by(veteran_icn: @current_user[:icn], tax_year: download_params[:tax_year])

      if @form.blank?
        Rails.logger.error("Form 1095-B for #{download_params[:tax_year]} not found", user_uuid: @current_user&.uuid)
        raise Common::Exceptions::RecordNotFound, download_params[:tax_year]
      end
    end

    def set_available_forms
      @available_forms = Form1095B.available_forms(@current_user[:icn])
    end

    def download_params
      params.permit(:tax_year)
    end
  end
end
