# frozen_string_literal: true

module V0
  class AverageDaysForClaimCompletionController < ApplicationController
    service_tag 'average-days-to-completion'
    skip_before_action :authenticate, only: :index

    def index
      rtn = AverageDaysForClaimCompletion.order('created_at DESC').first
      render json: {
        average_days: rtn.present? ? rtn.average_days : -1.0
      }
    end
  end
end
