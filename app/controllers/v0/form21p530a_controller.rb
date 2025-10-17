# frozen_string_literal: true

# Temporary stub implementation for Form 21P-530a to enable parallel frontend development
# This entire file will be replaced with the full implementation in Phase 1

module V0
  class Form21p530aController < ApplicationController
    service_tag 'burial-allowance-state-tribal'
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
            regional_office: [
              'Department of Veterans Affairs',
              'Pension Management Center',
              'P.O. Box 5365',
              'Janesville, WI 53547-5365'
            ],
            confirmation_number:,
            guid: confirmation_number,
            form: '21P-530a'
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
