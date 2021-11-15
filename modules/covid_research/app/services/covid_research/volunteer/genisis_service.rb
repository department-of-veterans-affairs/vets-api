# frozen_string_literal: true

# Base URL: https://vaausapprne60.aac.dva.va.gov/COVID19Service
# Endpoint: formdata
# Method: POST

# Username: COVTestUser
# Password: VAcovid-19test!

require 'common/client/base'
require 'common/client/concerns/monitoring'

module CovidResearch
  module Volunteer
    class GenisisService < Common::Client::Base
      include Common::Client::Concerns::Monitoring
      include SentryLogging

      STATSD_KEY_PREFIX = 'api.covid-research.volunteer'

      attr_reader :delivery_response, :serializer, :submission

      def initialize(form_data, ser = :default)
        @serializer = ser == :default ? GenisisSerializer.new : ser
        @submission = form_data
        @delivery_respone = :unattempted
      end

      def deliver_form
        with_monitoring do
          @delivery_response = post(payload)

          StatsD.increment("#{STATSD_KEY_PREFIX}.deliver_form.fail") unless @delivery_response.success?
        end
      end

      def payload
        serializer.serialize(JSON.parse(submission))
      end

      private

      def post(params)
        conn.post("#{Settings.genisis.service_path}/formdata", params, headers)
      end

      def headers
        {
          'Content-Type' => 'application/json'
        }
      end

      def conn
        c = Faraday.new(url: Settings.genisis.base_url)
        c.basic_auth(Settings.genisis.user, Settings.genisis.pass)

        c
      end
    end
  end
end
