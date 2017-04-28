# frozen_string_literal: true
module V0
  class HealthRecordsController < BBController
    include ActionController::Live

    REPORT_HEADERS = %w(Content-Type Content-Disposition).freeze

    def refresh
      resource = client.get_extract_status

      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: ExtractStatusSerializer,
             meta: resource.metadata
    end

    def eligible_data_classes
      resource = client.get_eligible_data_classes

      render json: resource,
             serializer: EligibleDataClassesSerializer,
             meta: resource.metadata
    end

    def create
      client.post_generate(params)

      render nothing: true, status: :accepted
    end

    def show
      # doc_type will default to 'pdf' if any value, including nil is provided.
      doc_type = params[:doc_type] == 'txt' ? 'txt' : 'pdf'
      header_callback = lambda do |headers|
        headers.each { |k, v| response[k] = v if REPORT_HEADERS.include? k }
      end
      begin
        chunk_stream = Enumerator.new do |stream|
          client.get_download_report(doc_type, header_callback, stream)
        end
        chunk_stream.each { |c| response.stream.write c }
      ensure
        response.stream.close if response.committed?
      end
    end
  end
end
