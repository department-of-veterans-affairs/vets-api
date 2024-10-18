# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class ImagingController < MrController
        def index
          resource = bb_client.list_imaging_studies
          render json: resource.to_json
        end

        # def request_study
        #   study_id = params[:id].try(:to_s)
        #   resource = bb_client.list_images(current_user.icn, study_id)
        #   render json: resource.to_json
        # end

        def images
          study_id = params[:id].try(:to_s)
          resource = bb_client.list_images(study_id)
          render json: resource.to_json
        end

        def dicom
          header_callback = lambda do |headers|
            headers.each do |k, v|
              request[k] = v if REPORT_HEADERS.include? k
            end
          end
          begin
            chunk_stream = Enumerator.new do |stream|
              bb_client.dicom(header_callback, stream)
            end
            chunk_stream.each { |c| response.stream.write c }
          ensure
            response.stream.close if response.committed?
          end
        end

        def img
          response.headers['Content-Type'] = 'image/jpeg'
          begin
            chunk_stream = Enumerator.new do |stream|
              bb_client.get_image(nil, stream)
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
