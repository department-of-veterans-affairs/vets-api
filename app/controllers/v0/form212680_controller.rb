# frozen_string_literal: true

# Temporary stub implementation for Form 21-2680 to enable parallel frontend development
# This entire file will be replaced with the full implementation in Phase 1

module V0
  class Form212680Controller < ApplicationController
    skip_before_action :authenticate
    service_tag 'form-21-2680'

    def download_pdf
      placeholder_response = {
        message: 'PDF generation stub - not yet implemented',
        instructions: {
          title: 'Next Steps: Get Physician to Complete Form',
          steps: [
            'Download the pre-filled PDF below',
            'Take the form to your physician',
            'Have your physician complete Sections VI-VIII',
            'Upload the completed form at: va.gov/upload-supporting-documents'
          ],
          upload_url: 'https://va.gov/upload-supporting-documents',
          form_number: '21-2680',
          regional_office: 'Department of Veterans Affairs, Pension Management Center,P.O. Box 5365, Janesville, WI 53547-5365'
        }
      }
      render json: placeholder_response
    end
  end
end
