# frozen_string_literal: true

module V0
  class Form21p530aController < ApplicationController
    service_tag 'state-tribal-interment-allowance'
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
            confirmation_number:,
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
