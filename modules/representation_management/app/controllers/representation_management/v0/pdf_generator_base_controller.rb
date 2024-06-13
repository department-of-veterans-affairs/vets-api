# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGeneratorBaseController < ApplicationController
      service_tag 'lighthouse-veteran' # Is this the correct service tag?
      before_action :feature_enabled
      # skip_before_action :authenticate

      # TODO:
      # Make a common validator for all addresses that we can pass the veteran, claimant, and representative addresses to.
      # Make a common validator for all names that we can pass the veteran and claimant names to.
      # Both of those will make this easier to read and reason about.

      def create
        # We'll need a process here to check the params to make sure all the
        # required fields are present. If not, we'll need to return an error
        # with status: :unprocessable_entity.  If all fields are accounted for
        # we need to fill out the 2122 PDF with the data and return the file
        # to the front end.

        # This work probably belongs in the PDF Generation ticket.
        render json: {}, status: :unprocessable_entity
      end

      private

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

      def verify_veteran_params
        # invoke all verify operations
        verify_veteran_address
        verify_veteran_name
        verify_veteran_identity
      end

      def string_present_and_less_than_max_length?(string, max_length)
        string.present? && string.is_a?(String) && string.size <= max_length
      end

      def string_present_and_equal_to_length?(string, length)
        string.present? && string.is_a?(String) && string.size == length
      end

      def raise_invalid_field_value(field_name, field_value)
        raise Common::Exceptions::InvalidFieldValue.new(field_name, field_value)
      end

      def verify_veteran_address
        unless string_present_and_greater_than_max_length?(form_params[:veteran_address_line1], 30)
          raise_invalid_field_value('veteran_address_line1', form_params[:veteran_address_line1])
        end

        if string_present_and_greater_than_max_length?(form_params[:veteran_address_line2], 50)
          raise_invalid_field_value('veteran_address_line2', form_params[:veteran_address_line2])
        end
        unless string_present_and_greater_than_max_length?(form_params[:veteran_city], 18)
          raise_invalid_field_value('veteran_city', form_params[:veteran_city])
        end
        unless string_present_and_equal_to_length?(form_params[:veteran_state_code], 2)
          raise_invalid_field_value('veteran_state_code', form_params[:veteran_state_code])
        end
        unless string_present_and_equal_to_length?(form_params[:veteran_zip_code], 5)
          raise_invalid_field_value('veteran_zip_code', form_params[:veteran_zip_code])
        end
        unless string_present_and_equal_to_length?(form_params[:veteran_zip_code_suffix], 4)
          raise_invalid_field_value('veteran_zip_code_suffix', form_params[:veteran_zip_code_suffix])
        end
      end

      def verify_veteran_name
        first_name = form_params[:veteran_first_name]
        middle_initial = form_params[:veteran_middle_initial]
        last_name = form_params[:veteran_last_name]
        unless first_name.present? && first_name.is_a?(String) && first_name.size > 12
          raise Common::Exceptions::InvalidFieldValue.new('veteran_first_name', form_params[:veteran_first_name])
        end

        if middle_initial.present? && middle_initial.is_a?(String) && middle_initial.size > 1
          raise Common::Exceptions::InvalidFieldValue.new('veteran_middle_initial',
                                                          form_params[:veteran_middle_initial])
        end
        unless last_name.present? && last_name.is_a?(String) && last_name.size > 18
          raise Common::Exceptions::InvalidFieldValue.new('veteran_last_name', form_params[:veteran_last_name])
        end
      end

      def verify_veteran_identity
        unless string_present_and_equal_to_length?(form_params[:veteran_social_security_number], 9)
          raise_invalid_field_value('veteran_social_security_number', form_params[:veteran_social_security_number])
        end
        if string_present_and_equal_to_length?(form_params[:veteran_file_number], 9)
          raise_invalid_field_value('veteran_file_number', form_params[:veteran_file_number])
        end
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
