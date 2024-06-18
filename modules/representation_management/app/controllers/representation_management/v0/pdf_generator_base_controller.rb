# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGeneratorBaseController < ApplicationController
      service_tag 'lighthouse-veteran' # Is this the correct service tag?
      before_action :feature_enabled
      before_action :verify_veteran_first_name_required
      before_action :verify_veteran_middle_initial_required
      before_action :verify_veteran_last_name_required
      before_action :verify_veteran_social_security_number_required
      before_action :verify_veteran_file_number_optional
      before_action :verify_veteran_address_line1_required
      before_action :verify_veteran_address_line2_optional
      before_action :verify_veteran_city_required
      before_action :verify_veteran_country_required
      before_action :verify_veteran_state_code_required
      before_action :verify_veteran_zip_code_required
      before_action :verify_veteran_zip_code_suffix_optional
      before_action :verify_veteran_area_code_optional
      before_action :verify_veteran_phone_number_optional
      before_action :verify_veteran_phone_number_ext_optional
      before_action :verify_veteran_email_optional
      before_action :verify_veteran_service_number_optional
      before_action :verify_veteran_insurance_number_optional

      before_action :verify_claimant_first_name_optional
      before_action :verify_claimant_middle_initial_optional
      before_action :verify_claimant_last_name_optional
      before_action :verify_claimant_address_line1_optional
      before_action :verify_claimant_address_line2_optional
      before_action :verify_claimant_city_optional
      before_action :verify_claimant_country_optional
      before_action :verify_claimant_state_code_optional
      before_action :verify_claimant_zip_code_optional
      before_action :verify_claimant_zip_code_suffix_optional
      before_action :verify_claimant_area_code_optional
      before_action :verify_claimant_phone_number_optional
      before_action :verify_claimant_phone_number_ext_optional
      before_action :verify_claimant_email_optional
      before_action :verify_claimant_relationship_optional

      skip_before_action :authenticate

      def create
        render json: {}, status: :unprocessable_entity
      end

      private

      def verify_veteran_first_name_required
        unless string_present_and_less_than_max_length?(form_params[:veteran_first_name], 12)
          raise_invalid_field_value('veteran_first_name', form_params[:veteran_first_name])
        end
      end

      def verify_veteran_middle_initial_required
        middle_initial = form_params[:veteran_middle_initial]
        if middle_initial.present? && !middle_initial.is_a?(String) && middle_initial.size != 1
          raise_invalid_field_value('veteran_middle_initial', form_params[:veteran_middle_initial])
        end
      end

      def verify_veteran_last_name_required
        unless string_present_and_less_than_max_length?(form_params[:veteran_last_name], 18)
          raise_invalid_field_value('veteran_last_name', form_params[:veteran_last_name])
        end
      end

      def verify_veteran_social_security_number_required
        unless string_present_and_equal_to_length?(form_params[:veteran_social_security_number], 9)
          raise_invalid_field_value('veteran_social_security_number', form_params[:veteran_social_security_number])
        end
      end

      def verify_veteran_file_number_optional
        if form_params[:veteran_file_number].present? &&
           !(form_params[:veteran_file_number].is_a?(String) ||
           form_params[:veteran_file_number].size != 9)
          raise_invalid_field_value('veteran_file_number', form_params[:veteran_file_number])
        end
      end

      def verify_veteran_address_line1_required
        unless string_present_and_less_than_max_length?(form_params[:veteran_address_line1], 30)
          raise_invalid_field_value('veteran_address_line1', form_params[:veteran_address_line1])
        end
      end

      def verify_veteran_address_line2_optional
        if form_params[:veteran_address_line2].present? &&
           (!form_params[:veteran_address_line2].is_a?(String) ||
           form_params[:veteran_address_line2].size > 5)
          raise_invalid_field_value('veteran_address_line2', form_params[:veteran_address_line2])
        end
      end

      def verify_veteran_city_required
        unless string_present_and_less_than_max_length?(form_params[:veteran_city], 18)
          raise_invalid_field_value('veteran_city', form_params[:veteran_city])
        end
      end

      def verify_veteran_country_required
        unless string_present_and_less_than_max_length?(form_params[:veteran_country], 2)
          raise_invalid_field_value('veteran_country', form_params[:veteran_country])
        end
      end

      def verify_veteran_state_code_required
        unless string_present_and_equal_to_length?(form_params[:veteran_state_code], 2)
          raise_invalid_field_value('veteran_state_code', form_params[:veteran_state_code])
        end
      end

      def verify_veteran_zip_code_required
        unless string_present_and_equal_to_length?(form_params[:veteran_zip_code], 5)
          raise_invalid_field_value('veteran_zip_code', form_params[:veteran_zip_code])
        end
      end

      def verify_veteran_zip_code_suffix_optional
        if form_params[:veteran_zip_code_suffix].present? &&
           !(form_params[:veteran_zip_code_suffix].is_a?(String) ||
           form_params[:veteran_zip_code_suffix].size != 4)
          raise_invalid_field_value('veteran_zip_code_suffix', form_params[:veteran_zip_code_suffix])
        end
      end

      def verify_veteran_area_code_optional
        if form_params[:veteran_area_code].present? &&
           !(form_params[:veteran_area_code].is_a?(String) ||
           form_params[:veteran_area_code].size != 3)
          raise_invalid_field_value('veteran_area_code', form_params[:veteran_area_code])
        end
      end

      def verify_veteran_phone_number_optional
        if form_params[:veteran_phone_number].present? &&
           !(form_params[:veteran_phone_number].is_a?(String) ||
           form_params[:veteran_phone_number].size != 7)
          raise_invalid_field_value('veteran_phone_number', form_params[:veteran_phone_number])
        end
      end

      def verify_veteran_phone_number_ext_optional
        if form_params[:veteran_phone_number_ext].present? &&
           !form_params[:veteran_phone_number_ext].is_a?(String)
          raise_invalid_field_value('veteran_phone_number_ext', form_params[:veteran_phone_number_ext])
        end
      end

      def verify_veteran_email_optional
        if form_params[:veteran_email].present? &&
           !form_params[:veteran_email].is_a?(String)
          raise_invalid_field_value('veteran_email', form_params[:veteran_email])
        end
      end

      def verify_veteran_service_number_optional
        if form_params[:veteran_service_number].present? &&
           !(form_params[:veteran_service_number].is_a?(String) ||
           form_params[:veteran_service_number].size != 9)
          raise_invalid_field_value('veteran_service_number', form_params[:veteran_service_number])
        end
      end

      def verify_veteran_insurance_number_optional
        if form_params[:veteran_insurance_number].present? &&
           !form_params[:veteran_insurance_number].is_a?(String)
          raise_invalid_field_value('veteran_insurance_number', form_params[:veteran_insurance_number])
        end
      end

      def verify_claimant_first_name_optional
        if form_params[:claimant_first_name].present? &&
           (!form_params[:claimant_first_name].is_a?(String) ||
           form_params[:claimant_first_name].size > 12)
          raise_invalid_field_value('claimant_first_name', form_params[:claimant_first_name])
        end
      end

      def verify_claimant_middle_initial_optional
        if form_params[:claimant_middle_initial].present? &&
           form_params[:claimant_first_name].present? &&
           (!form_params[:claimant_middle_initial].is_a?(String) ||
           form_params[:claimant_middle_initial].size != 1)
          raise_invalid_field_value('claimant_middle_initial', form_params[:claimant_middle_initial])
        end
      end

      def verify_claimant_last_name_optional
        if form_params[:claimant_last_name].present? &&
           form_params[:claimant_first_name].present? &&
           (!form_params[:claimant_last_name].is_a?(String) ||
           form_params[:claimant_last_name].size > 18)
          raise_invalid_field_value('claimant_last_name', form_params[:claimant_last_name])
        end
      end

      def verify_claimant_address_line1_optional
        if form_params[:claimant_address_line1].present? &&
           form_params[:claimant_first_name].present? &&
           string_present_and_less_than_max_length?(form_params[:claimant_address_line1], 30)
          raise_invalid_field_value('claimant_address_line1', form_params[:claimant_address_line1])
        end
      end

      def verify_claimant_address_line2_optional
        if form_params[:claimant_address_line2].present? &&
           form_params[:claimant_first_name].present? &&
           (!form_params[:claimant_address_line2].is_a?(String) ||
           form_params[:claimant_address_line2].size > 5)
          raise_invalid_field_value('claimant_address_line2', form_params[:claimant_address_line2])
        end
      end

      def verify_claimant_city_optional
        if form_params[:claimant_first_name].present? &&
           !string_present_and_less_than_max_length?(form_params[:claimant_city], 18)
          raise_invalid_field_value('claimant_city', form_params[:claimant_city])
        end
      end

      def verify_claimant_country_optional
        if form_params[:claimant_first_name].present? &&
           !string_present_and_less_than_max_length?(form_params[:claimant_country], 2)
          raise_invalid_field_value('claimant_country', form_params[:claimant_country])
        end
      end

      def verify_claimant_state_code_optional
        if form_params[:claimant_first_name].present? &&
           !string_present_and_equal_to_length?(form_params[:claimant_state_code], 2)
          raise_invalid_field_value('claimant_state_code', form_params[:claimant_state_code])
        end
      end

      def verify_claimant_zip_code_optional
        if form_params[:claimant_first_name].present? &&
           !string_present_and_equal_to_length?(form_params[:claimant_zip_code], 5)
          raise_invalid_field_value('claimant_zip_code', form_params[:claimant_zip_code])
        end
      end

      def verify_claimant_zip_code_suffix_optional
        if form_params[:claimant_first_name].present? &&
           form_params[:claimant_zip_code_suffix].present? &&
           (!form_params[:claimant_zip_code_suffix].is_a?(String) ||
           form_params[:claimant_zip_code_suffix].size != 4)
          raise_invalid_field_value('claimant_zip_code_suffix', form_params[:claimant_zip_code_suffix])
        end
      end

      def verify_claimant_area_code_optional
        if form_params[:claimant_first_name].present? &&
           form_params[:claimant_area_code].present? &&
           (!form_params[:claimant_area_code].is_a?(String) ||
           form_params[:claimant_area_code].size != 3)
          raise_invalid_field_value('claimant_area_code', form_params[:claimant_area_code])
        end
      end

      def verify_claimant_phone_number_optional
        if form_params[:claimant_first_name].present? &&
           form_params[:claimant_phone_number].present? &&
           (!form_params[:claimant_phone_number].is_a?(String) ||
           form_params[:claimant_phone_number].size != 7)
          raise_invalid_field_value('claimant_phone_number', form_params[:claimant_phone_number])
        end
      end

      def verify_claimant_phone_number_ext_optional
        if form_params[:claimant_first_name].present? &&
           form_params[:claimant_phone_number_ext].present? &&
           !form_params[:claimant_phone_number_ext].is_a?(String)
          raise_invalid_field_value('claimant_phone_number_ext', form_params[:claimant_phone_number_ext])
        end
      end

      def verify_claimant_email_optional
        if form_params[:claimant_first_name].present? &&
           form_params[:claimant_email].present? &&
           !form_params[:claimant_email].is_a?(String)
          raise_invalid_field_value('claimant_email', form_params[:claimant_email])
        end
      end

      def form_params
        params.permit(all_params)
      end

      def claimant_params
        %i[
          claimant_address_line1
          claimant_address_line2
          claimant_city
          claimant_country
          claimant_state_code
          claimant_zip_code
          claimant_zip_code_suffix
          claimant_area_code
          claimant_phone_number
          claimant_phone_number_ext
          claimant_email
          claimant_relationship
        ]
      end

      def representative_params
        %i[
          poa_code
          registration_number
          type
          representative_address_line1
          representative_address_line2
          representative_city
          representative_country
          representative_state_code
          representative_zip_code
          representative_zip_code_suffix
        ]
      end

      def service_organization_params
        %i[
          service_organization_poa_code
          service_organization_registration_number
          service_organization_job_title
          service_organization_email
          service_organization_appointment_date

        ]
      end

      def string_present_and_less_than_max_length?(string, max_length)
        string.present? && string.is_a?(String) && string.size <= max_length
      end

      def string_present_and_greater_than_max_length?(string, max_length)
        string.present? && string.is_a?(String) && string.size > max_length
      end

      def string_present_and_equal_to_length?(string, length)
        string.present? && string.is_a?(String) && string.size == length
      end

      def raise_invalid_field_value(field_name, field_value)
        raise Common::Exceptions::InvalidFieldValue.new(field_name, field_value)
      end

      def veteran_params
        %i[
          veteran_first_name veteran_middle_initial veteran_last_name
          veteran_social_security_number
          veteran_file_number
          veteran_address_line1
          veteran_address_line2
          veteran_city
          veteran_country
          veteran_state_code
          veteran_zip_code
          veteran_zip_code_suffix
          veteran_area_code
          veteran_phone_number
          veteran_phone_number_ext
          veteran_email
          veteran_service_number
          veteran_insurance_number
        ]
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_pdf)
      end
    end
  end
end
