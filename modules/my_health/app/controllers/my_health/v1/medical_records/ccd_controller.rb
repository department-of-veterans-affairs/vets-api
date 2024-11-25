# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class CcdController < MrController
        # Generates a CCD
        # @return [Array] of objects with CCDs generated date and status (COMPLETE or not)
        def generate
          resource = bb_client.get_generate_ccd(@current_user.icn, @current_user.last_name)
          render json: resource.to_json
        end

        # Downloads the CCD once it has been generated
        # @param generated_datetime [String] date receieved from get_generate_ccd call property dateGenerated
        # @return [XML] Continuity of Care Document
        def download
          generated_datetime = params[:date].to_s
          raise Common::Exceptions::ParameterMissing, 'date' if generated_datetime.blank?

          resource = bb_client.get_download_ccd(generated_datetime)
          send_data resource, type: 'application/xml'
        end
      end
    end
  end
end
