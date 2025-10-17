# frozen_string_literal: true

module V0
  class Form214192Controller < ApplicationController
    include RetriableConcern

    service_tag 'employment-information'
    skip_before_action :authenticate, only: %i[create download_pdf]

    before_action :feature_enabled?
    before_action :record_submission_attempt, only: :create

    def create
      claim = SavedClaim::Form214192.new(form: form_params.to_json)

      if claim.save
        claim.process_attachments!

        Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
        claim.send_confirmation_email

        render json: SavedClaimSerializer.new(claim)
      else
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
    rescue => e
      Rails.logger.error('Form214192: error submitting claim', { error: e.message })
      raise e
    end

    def download_pdf
      parsed_form = params[:form].is_a?(String) ? JSON.parse(params[:form]) : params[:form].to_unsafe_h

      # Convert snake_case keys to camelCase for PDF generation
      camel_case_form = convert_keys_to_camel_case(parsed_form)
      file_name = SecureRandom.uuid

      source_file_path = with_retries('Generate 21-4192 PDF') do
        PdfFill::Filler.fill_ancillary_form(camel_case_form, file_name, '21-4192')
      end

      employer_name = parsed_form.dig('employment_information', 'employer_name')
      file_path_name = employer_name ? employer_name.gsub(/[^0-9A-Za-z]/, '_') : '21-4192'
      client_file_name = "#{file_path_name}_21-4192_#{Time.zone.now.to_i}.pdf"

      file_contents = File.read(source_file_path)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    private

    def feature_enabled?
      routing_error unless Flipper.enabled?(:form_214192_enabled)
    end

    def record_submission_attempt
      StatsD.increment("#{stats_key}.submission_attempt")
    end

    def form_params
      params.require(:form214192)
    end

    def stats_key
      'api.form214192'
    end

    def convert_keys_to_camel_case(hash)
      case hash
      when Hash
        hash.transform_keys { |key| key.to_s.camelize(:lower) }
            .transform_values { |value| convert_keys_to_camel_case(value) }
      when Array
        hash.map { |item| convert_keys_to_camel_case(item) }
      else
        hash
      end
    end
  end
end
