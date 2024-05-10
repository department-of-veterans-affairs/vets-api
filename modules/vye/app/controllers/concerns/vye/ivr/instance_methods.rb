# frozen_string_literal: true

module Vye
  module Ivr
    module InstanceMethods
      private

      def ivr_params
        transformed_params.permit(%i[api_key file_number])
      end

      def api_key
        ivr_params[:api_key]
      end

      protected

      def file_number
        ivr_params[:file_number]
      end

      def api_key?
        api_key.present? && api_key == api_key_actual
      end

      def user_info_for_ivr(scoped: Vye::UserProfile)
        # file_number_digest = Vye::UserProfile.gen_digest(file_number)
        # scoped.find_by(file_number_digest:)&.active_user_info

        scoped.find_from_digested_file_number(file_number)&.active_user_info
      end
    end
  end
end
