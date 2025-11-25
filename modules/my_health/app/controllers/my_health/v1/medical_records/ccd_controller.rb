# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class CcdController < MRController
        include MyHealth::AALClientConcerns

        ##
        # Generates a CCD
        # @return [Array] of objects with CCDs generated date and status (COMPLETE or not)
        #
        def generate
          resource = bb_client.get_generate_ccd(current_user.icn, current_user.last_name)
          render json: resource.to_json
        rescue => e
          log_aal_action('Download My VA Health Summary', 0)
          raise e
        end

        ##
        # Downloads the CCD after it has been generated.
        # Uses Rails format negotiation: /ccd/download.xml|.html|.pdf?date=...
        # Defaults to XML when no format is supplied (route should set defaults: { format: 'xml' }).
        #
        # @param date [String] date received from get_generate_ccd call property dateGenerated
        # @return [XML|PDF|HTML] Continuity of Care Document
        #
        def download
          fmt = requested_format

          body = handle_aal_action('Download My VA Health Summary') do
            generated_datetime = params[:date].to_s
            raise Common::Exceptions::ParameterMissing, 'date' if generated_datetime.blank?

            bb_client.get_download_ccd(date: generated_datetime, format: fmt)
          end

          deliver_ccd(body, fmt)
        end

        def product
          :mr
        end

        private

        def deliver_ccd(body, fmt)
          case fmt
          when :xml
            send_data body,
                      type: 'application/xml; charset=utf-8',
                      disposition: 'attachment'
          when :html
            send_data body,
                      type: 'text/html; charset=utf-8',
                      disposition: 'attachment'
          when :pdf
            send_data body,
                      type: 'application/pdf',
                      disposition: 'attachment'
          else
            head :not_acceptable
          end
        end

        ##
        # Ensures only the formats we support are accepted; defaults to :xml.
        #
        def requested_format
          fmt =
            (params[:format].presence ||
             request.format&.symbol&.to_s ||
             'xml').to_s.downcase

          case fmt
          when 'html' then :html
          when 'pdf'  then :pdf
          else
            :xml
          end
        end

        def handle_aal_action(action_description)
          response = yield
          log_aal_action(action_description, 1)
          response
        rescue => e
          log_aal_action(action_description, 0)
          raise e
        end

        def log_aal_action(action, status)
          create_aal({
                       activity_type: 'Download',
                       action:,
                       performer_type: 'Self',
                       status:
                     })
        end
      end
    end
  end
end
