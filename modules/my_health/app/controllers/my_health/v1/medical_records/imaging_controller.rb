# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class ImagingController < MrController
        def index
          resource = bb_client.list_imaging_studies
          render json: resource.to_json
        end

        def request_download
          study_id = params[:id].try(:to_s)
          resource = bb_client.request_study(study_id)
          render json: resource.to_json
        end

        def images
          study_id = params[:id].try(:to_s)
          resource = bb_client.list_images(study_id)
          render json: resource.to_json
        end

        def image
          study_id = params[:id].to_s
          series_id = params[:series_id].to_s
          image_id = params[:image_id].to_s
          response.headers['Content-Type'] = 'image/jpeg'
          begin
            chunk_stream = Enumerator.new do |stream|
              bb_client.get_image(study_id, series_id, image_id, nil, stream)
            end
            chunk_stream.each { |c| response.stream.write c }
          ensure
            response.stream.close if response.committed?
          end
        end

        def dicom
          study_id = params[:id].try(:to_s)

          # Lambda to capture headers from the upstream response
          header_callback = lambda do |headers|
            headers.each do |k, v|
              response.headers[k] = v if k.present?
            end
          end

          begin
            chunk_stream = Enumerator.new do |stream|
              bb_client.get_dicom(study_id, header_callback, stream)
            end
            chunk_stream.each { |c| response.stream.write c }
          ensure
            response.stream.close if response.committed?
          end
        end
      end
    end
  end
end
