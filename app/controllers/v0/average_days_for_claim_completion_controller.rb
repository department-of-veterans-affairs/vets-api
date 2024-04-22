# frozen_string_literal: true

module V0
  class AverageDaysForClaimCompletionController < ApplicationController
    service_tag 'average-days-to-completion'
    skip_before_action :authenticate, only: :index

    def connection
      @conn ||= Faraday.new('https://www.va.gov/') do |faraday|
        faraday.use      :breakers
        faraday.use      Faraday::Response::RaiseError

        faraday.request :json

        faraday.response :json, content_type: /\bjson/
        faraday.adapter Faraday.default_adapter
      end
    end

    AVERAGE_DAYS_REGEX = /(([0-9]{1,3}(\.[0-9]{1,2})) days)/

    def load_average_days
      rtn = connection.get('/disability/after-you-file-claim/').body
      rec = AverageDaysForClaimCompletion.new
      rec.average_days = AVERAGE_DAYS_REGEX.match(rtn)[2].to_f
      rec.save!
    end

    def index
      load_average_days
      rtn = AverageDaysForClaimCompletion.order('created_at DESC').first
      render json: {
        average_days: rtn.present? ? rtn.average_days : -1.0
      }
    end
  end
end
