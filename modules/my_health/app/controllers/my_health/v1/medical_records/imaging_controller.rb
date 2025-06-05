# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class ImagingController < MRController
        include ActionController::Live

        before_action :set_study_id, only: %i[request_download images image dicom]

        def index
          render_resource(bb_client.list_imaging_studies)
        end

        def request_download
          render_resource(bb_client.request_study(@study_id))
        end

        def request_status
          render_resource(bb_client.get_study_status)
        end

        def images
          render_resource(bb_client.list_images(@study_id))
        end

        def image
          response.headers['Content-Type'] = 'image/jpeg'
          stream_data do |stream|
            bb_client.get_image(@study_id, params[:series_id].to_s, params[:image_id].to_s, header_callback, stream)
          end
        end

        def dicom
          # Disable ETag manually to omit the "Content-Length" header for this streaming resource.
          # Otherwise the download/save dialog doesn't appear until after the file fully downloads.
          headers['ETag'] = nil

          response.headers['Content-Type'] = 'application/zip'
          stream_data do |stream|
            bb_client.get_dicom(@study_id, header_callback, stream)
          end
        end

        private

        def set_study_id
          @study_id = params[:id].to_s
        end

        def render_resource(resource)
          render json: resource.to_json
        end

        def header_callback
          lambda do |headers|
            headers.each do |k, v|
              next if %w[Content-Type Transfer-Encoding Content-Encoding].include?(k)

              response.headers[k] = v if k.present?
            end
          end
        end

        def stream_data(&)
          chunk_stream = Enumerator.new(&)
          chunk_stream.each { |chunk| response.stream.write(chunk) }
        ensure
          response.stream.close if response.committed?
        end
      end
    end
  end
end
