# frozen_string_literal: true

# Temporary stub implementation for Form 21-2680 to enable parallel frontend development
# This entire file will be replaced with the full implementation in Phase 1

module V0
  class Form212680Controller < ApplicationController
    skip_before_action :authenticate
    service_tag 'form-21-2680'

    def download_pdf
      render json: {
        message: 'PDF generation stub - not yet implemented'
      }, status: :ok
    end
  end
end
