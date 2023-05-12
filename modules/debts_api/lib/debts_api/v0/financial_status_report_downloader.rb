# frozen_string_literal: true

require 'net/http'
require 'uri'

module DebtsApi
  class V0::FinancialStatusReportDownloader
    class FilenetIdNotPresent < StandardError; end

    def initialize(financial_status_report)
      @financial_status_report = financial_status_report
    end

    def download_pdf
      id = @financial_status_report.filenet_id

      raise FilenetIdNotPresent if id.blank?

      uri = URI.parse(
        "#{Settings.dmc.url}financial-status-report/documentstream?objectId=#{id}"
      )
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      http.use_ssl = true

      request_headers.each { |header, value| request[header] = value }
      response = http.request(request)
      response.body
    end

    private

    def request_headers
      {
        Accept: 'application/pdf',
        client_id: Settings.dmc.client_id,
        client_secret: Settings.dmc.client_secret
      }
    end
  end
end
