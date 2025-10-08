# frozen_string_literal: true
# Temporary stub implementation for Form 21-0779 to enable parallel frontend development
# This entire file will be replaced with the full implementation in Phase 1

module V0
  class Form210779Controller < ApplicationController
    skip_before_action :authenticate

    def create
      confirmation_number = SecureRandom.uuid
      submitted_at = Time.current

      render json: {
        data: {
          id: '12345',
          type: 'saved_claims',
          attributes: {
            submitted_at: submitted_at.iso8601,
            regional_office: [],
            confirmation_number: confirmation_number,
            guid: confirmation_number,
            form: '21-0779'
          }
        }
      }, status: :ok
    end

    def download_pdf
      render json: {
        message: 'PDF download stub - not yet implemented'
      }, status: :ok
    end
  end
end
