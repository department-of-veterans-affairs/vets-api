# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGenerator2122aController < RepresentationManagement::V0::PdfGeneratorBaseController
      # service_tag 'lighthouse-veteran' # Is this the correct service tag?
      before_action :verify_representative_type_required
      before_action :verify_representative_first_name_required
      before_action :verfiy_representative_middle_initial_required
      before_action :verify_representative_last_name_required
      before_action :verify_representative_address_line1_required
      before_action :verify_representative_address_line2_optional
      before_action :verify_representative_city_required
      before_action :verify_representative_country_required
      before_action :verify_representative_state_code_required
      before_action :verify_representative_zip_code_required
      before_action :verify_representative_zip_code_suffix_optional
      before_action :verify_representative_area_code_required
      before_action :verify_representative_phone_number_required
      before_action :verify_representative_email_address_optional

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

      def all_params
        [
          claimant_params,
          representative_params,
          veteran_params,
          :record_consent,
          :consent_address_change,
          { consent_limits: [],
            conditions_of_appointment: [] }
        ].flatten
      end

      def verify_representative_type_required
        unless form_params[:representative_type].present? &&
               form_params[:representative_type].is_a?(String)
          raise_invalid_field_value('representative_type', form_params[:representative_type])
        end
      end

      def verify_representative_first_name_required
        unless form_params[:representative_first_name].present? &&
               string_present_and_less_than_max_length?(form_params[:representative_first_name], 12)
          raise_invalid_field_value('representative_first_name', form_params[:representative_first_name])
        end
      end

      def verfiy_representative_middle_initial_required
        unless form_params[:representative_middle_initial].present? &&
               string_present_and_equal_to_length?(form_params[:representative_middle_initial], 1)
          raise_invalid_field_value('representative_middle_initial', form_params[:representative_middle_initial])
        end
      end

      def verify_representative_last_name_required
        unless form_params[:representative_last_name].present? &&
               string_present_and_less_than_max_length?(form_params[:representative_last_name], 18)
          raise_invalid_field_value('representative_last_name', form_params[:representative_last_name])
        end
      end

      def verify_representative_address_line1_required
        unless form_params[:representative_address_line1].present? &&
               string_present_and_less_than_max_length?(form_params[:representative_address_line1], 30)
          raise_invalid_field_value('representative_address_line1', form_params[:representative_address_line1])
        end
      end

      def verify_representative_address_line2_optional
        if form_params[:representative_address_line2].present? &&
           (!form_params[:representative_address_line2].is_a?(String) ||
           form_params[:representative_address_line2].size > 5)
          raise_invalid_field_value('representative_address_line2', form_params[:representative_address_line2])
        end
      end

      def verify_representative_city_required
        unless form_params[:representative_city].present? &&
               string_present_and_less_than_max_length?(form_params[:representative_city], 18)
          raise_invalid_field_value('representative_city', form_params[:representative_city])
        end
      end

      def verify_representative_country_required
        unless form_params[:representative_country].present? &&
               string_present_and_equal_to_length?(form_params[:representative_country], 2)
          raise_invalid_field_value('representative_country', form_params[:representative_country])
        end
      end

      def verify_representative_state_code_required
        unless form_params[:representative_state_code].present? &&
               string_present_and_equal_to_length?(form_params[:representative_state_code], 2)
          raise_invalid_field_value('representative_state_code', form_params[:representative_state_code])
        end
      end

      def verify_representative_zip_code_required
        unless form_params[:representative_zip_code].present? &&
               string_present_and_equal_to_length?(form_params[:representative_zip_code], 5)
          raise_invalid_field_value('representative_zip_code', form_params[:representative_zip_code])
        end
      end

      def verify_representative_zip_code_suffix_optional
        if form_params[:representative_zip_code_suffix].present? &&
           (!form_params[:representative_zip_code_suffix].is_a?(String) ||
           form_params[:representative_zip_code_suffix].size != 4)
          raise_invalid_field_value('representative_zip_code_suffix', form_params[:representative_zip_code_suffix])
        end
      end

      def verify_representative_area_code_required
        unless form_params[:representative_area_code].present? &&
               string_present_and_equal_to_length?(form_params[:representative_area_code], 3)
          raise_invalid_field_value('representative_area_code', form_params[:representative_area_code])
        end
      end

      def verify_representative_phone_number_required
        unless form_params[:representative_phone_number].present? &&
               string_present_and_equal_to_length?(form_params[:representative_phone_number], 7)
          raise_invalid_field_value('representative_phone_number', form_params[:representative_phone_number])
        end
      end

      def verify_representative_email_address_optional
        if form_params[:representative_email_address].present? &&
           !form_params[:representative_email_address].is_a?(String)
          raise_invalid_field_value('representative_email_address', form_params[:representative_email_address])
        end
      end

      def representative_params
        %i[
          representative_type
          representative_service_organization_name
          representative_first_name
          representative_middle_initial
          representative_last_name
          representative_address_line1
          representative_address_line2
          representative_city
          representative_country
          representative_state_code
          representative_zip_code
          representative_zip_code_suffix
          representative_area_code
          representative_phone_number
          representative_email_address
        ]
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_pdf)
      end
    end
  end
end
