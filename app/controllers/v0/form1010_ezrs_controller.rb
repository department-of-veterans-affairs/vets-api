# frozen_string_literal: true

require 'form1010_ezr/service'
require 'pdf_fill/filler'

module V0
  class Form1010EzrsController < ApplicationController
    include RetriableConcern
    include PdfFilenameGenerator

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

      client_file_name = file_name_for_pdf(parsed_form, 'veteranFullName', '10-10EZR')
      file_contents    = File.read(source_file_path)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    def service_history
      p "~~~~~ ezr#service_history w/ icn? #{@current_user.icn.present?}"
      begin
        response = service.get_service_history(@current_user.icn)
        p "~~~~~ ezr#service_history resp", response
        p "~~~~~ ezr#service_history resp data", response['data']
      rescue => e
        p "~~~~~ ezr#service_history err", e
      end

      # LH returns the ICN of the Veteran in the data.id field
      # We want to scrub it out before sending to the FE
      # response["data']['id'] = ''

      render json: response
    end

    private

    def record_submission_attempt
      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.submission_attempt")
    end

    def parse_form(form)
      JSON.parse(form)
    end
  end
end
