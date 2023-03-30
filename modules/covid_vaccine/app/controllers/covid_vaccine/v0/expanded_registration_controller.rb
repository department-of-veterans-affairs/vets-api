# frozen_string_literal: true

require_relative '../../../serializers/covid_vaccine/v0/expanded_registration_serializer'

module CovidVaccine
  module V0
    class ExpandedRegistrationController < CovidVaccine::ApplicationController
      skip_before_action :validate_session
      before_action :validate_raw_form_data, only: :create
      wrap_parameters :registration

      def create
        raw_form_data = params[:registration]
        record = CovidVaccine::V0::ExpandedRegistrationSubmission.create!({ submission_uuid: SecureRandom.uuid,
                                                                            raw_form_data: })
        audit_log(raw_form_data)
        CovidVaccine::ExpandedRegistrationEmailJob.perform_async(record.id) if raw_form_data['email_address'].present?
        render json: record, serializer: CovidVaccine::V0::ExpandedRegistrationSerializer, status: :created
      end

      private

      def validate_raw_form_data
        form_data = CovidVaccine::V0::RawExpandedFormData.new(params[:registration] || {})
        raise Common::Exceptions::ValidationErrors, form_data unless form_data.valid?
      end

      def check_flipper
        routing_error unless Flipper.enabled?(:covid_vaccine_registration_expanded)
      end

      def audit_log(raw_form_data)
        log_attrs = {
          applicant_type: raw_form_data[:applicant_type],
          country_name: raw_form_data[:country_name],
          state_code: raw_form_data[:state_code],
          preferred_facility: raw_form_data[:preferred_facility],
          has_email: raw_form_data[:email_address].present?,
          sms_acknowledgement: raw_form_data[:sms_acknowledgement]
        }
        Rails.logger.info('Covid_Vaccine Expanded_Submission', log_attrs.to_json)
      end
    end
  end
end
