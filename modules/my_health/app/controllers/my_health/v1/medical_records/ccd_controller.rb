# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class CcdController < MRController
        # Enables response streaming to avoid buffering large CCD documents in memory.
        # ActionController::Live allows writing response chunks incrementally via response.stream
        include ActionController::Live
        include MyHealth::AALClientConcerns

        CCD_HEADERS = %w[Content-Type Content-Disposition].freeze

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
        # Streams the document without buffering entire content in memory.
        #
        # @param date [String] date received from get_generate_ccd call property dateGenerated
        # @return [XML|PDF|HTML] Continuity of Care Document (streamed)
        #
        def download
          fmt = requested_format
          generated_datetime = params[:date].to_s
          raise Common::Exceptions::ParameterMissing, 'date' if generated_datetime.blank?

          set_response_headers(fmt)
          stream_ccd_response(generated_datetime, fmt)
        end

        def product
          :mr
        end

        private

        ##
        # Streams the CCD response to the client with AAL logging
        #
        def stream_ccd_response(generated_datetime, fmt)
          chunk_stream = Enumerator.new do |stream|
            bb_client.stream_download_ccd(
              date: generated_datetime,
              format: fmt,
              header_callback:,
              yielder: stream
            )
          end

          chunk_stream.each { |chunk| response.stream.write(chunk) }
          log_aal_action('Download My VA Health Summary', 1)
        rescue => e
          log_aal_action('Download My VA Health Summary', 0)
          raise e
        ensure
          response.stream.close if response.committed?
        end

        ##
        # Sets appropriate Content-Type header based on requested format
        #
        def set_response_headers(fmt)
          content_types = {
            xml: 'application/xml; charset=utf-8',
            html: 'text/html; charset=utf-8',
            pdf: 'application/pdf'
          }
          response.headers['Content-Type'] = content_types[fmt]
          response.headers['Content-Disposition'] = 'attachment'
        end

        ##
        # Callback for handling response headers during streaming
        #
        def header_callback
          lambda do |headers|
            headers.each { |k, v| response.headers[k] = v if CCD_HEADERS.include?(k) }
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
