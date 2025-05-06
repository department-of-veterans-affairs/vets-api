# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class CcdController < MrController
        include MyHealth::AALClientConcerns

        # Generates a CCD
        # @return [Array] of objects with CCDs generated date and status (COMPLETE or not)
        def generate
          resource = bb_client.get_generate_ccd(current_user.icn, current_user.last_name)
          render json: resource.to_json
        rescue => e
          log_aal_action('Download My VA Health Summary', 0)
          raise e
        end

        # Downloads the CCD once it has been generated
        # @param generated_datetime [String] date receieved from get_generate_ccd call property dateGenerated
        # @return [XML] Continuity of Care Document
        def download
          resource = handle_aal_action('Download My VA Health Summary') do
            generated_datetime = params[:date].to_s
            raise Common::Exceptions::ParameterMissing, 'date' if generated_datetime.blank?

            bb_client.get_download_ccd(generated_datetime)
          end
          send_data resource, type: 'application/xml'
        end

        def product
          :mr
        end

        private

        def handle_aal_action(action_description)
          response = yield
          log_aal_action(action_description, 1)
          response
        rescue => e
          log_aal_action(action_description, 0)
          raise e
        end

        def log_aal_action(action, status)
          aal_client.create_aal(
            activity_type: 'Download',
            action:,
            performer_type: 'Self',
            status:
          )
        end
      end
    end
  end
end
