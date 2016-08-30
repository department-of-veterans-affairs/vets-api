require_dependency "evss/base_service"

module EVSS
  class DocumentsService < BaseService
    def initialize(vaafi_headers = {})
      super()
      # TODO: Get base URI from env
      @base_url = "http://csraciapp6.evss.srarad.com:7003/wss-document-services-web-3.1/rest/"
      @headers = vaafi_headers
    end

    def all_documents
      get "documents/getAllDocuments"
    end
  end
end
