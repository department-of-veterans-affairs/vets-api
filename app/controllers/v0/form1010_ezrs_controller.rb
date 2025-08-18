# frozen_string_literal: true

require 'form1010_ezr/service'
require 'pdf_fill/filler'

module V0
  class Form1010EzrsController < ApplicationController
    include RetriableConcern

    service_tag 'health-information-update'

    before_action :record_submission_attempt, only: :create

    def create
      parsed_form = parse_form(params[:form])

      result = Form1010Ezr::Service.new(@current_user).submit_form(parsed_form)

      clear_saved_form('10-10EZR')

      render(json: result)
    end

    def download_pdf
      parsed_form = parse_form(params[:form])
      file_name = SecureRandom.uuid

      source_file_path = with_retries('Generate 10-10EZR PDF') do
        PdfFill::Filler.fill_ancillary_form(parsed_form, file_name, '10-10EZR')
      end

      client_file_name = file_name_for_pdf(parsed_form)
      file_contents    = File.read(source_file_path)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    private

    def record_submission_attempt
      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.submission_attempt")
    end

    def parse_form(form)
      JSON.parse(form)
    end

    def file_name_for_pdf(parsed_form)
      veteran_name = parsed_form.try(:[], 'veteranFullName')
      first_name = veteran_name.try(:[], 'first') || 'First'
      last_name = veteran_name.try(:[], 'last') || 'Last'
      "10-10EZR_#{first_name}_#{last_name}.pdf"
    end
  end
end
