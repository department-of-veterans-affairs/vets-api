# frozen_string_literal: true
module V0
  class HealthRecordsController < BBController
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
      resource = client.get_download_report(doc_type)

      send_data resource.body,
                type: resource.response_headers['content-type'],
                disposition: resource.response_headers['content-disposition']
    end
  end
end
