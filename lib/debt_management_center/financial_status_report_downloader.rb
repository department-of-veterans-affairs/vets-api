# frozen_string_literal: true

require 'net/http'
require 'uri'

module DebtManagementCenter
  class FinancialStatusReportDownloader
    def initialize(financial_status_report)
      @financial_status_report = financial_status_report
    end

    def base_url
      Settings.dmc.url
    end

    def request_headers
      {
        Accept: 'application/pdf',
        client_id: Settings.dmc.client_id,
        client_secret: Settings.dmc.client_secret
      }
    end

    def download_pdf
      uri = URI.parse(
        "#{Settings.dmc.url}financial-status-report/documentstream?objectId=#{@financial_status_report.filenet_id}"
      )
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)

      request_headers.each { |header, value| request[header] = value }
      response = http.request(request)
      response.body
    end
  end
end
