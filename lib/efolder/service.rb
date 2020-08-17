# frozen_string_literal: true

module Efolder
  ## Veteran Facing eFolder
  #
  # This service provides the veteran with methods to
  # both view the contents of their eFolder, and
  # also download the files contained therein.
  #

  # EXCLUDED_DOC_TYPES
  #
  # The doc_types within EXCLUDED_DOC_TYPES
  # should never be exposed to the veteran.
  #

  EXCLUDED_DOC_TYPES = YAML.load(Rails.root.join('lib', 'efolder', 'excluded_doc_types.yml')).freeze

  class Service
    attr_accessor :file_number, :included_doc_types

    def initialize
      yield self
      @client = VBMS::Client.from_env_vars(env_name: Settings.vbms.env)
    end

    def list_documents
      documents = @client.send_request(
        VBMS::Requests::FindDocumentVersionReference.new(@file_number)
      )

      if @included_doc_types.present?
        documents = documents.find_all do |record|
          @included_doc_types.include?(record.doc_type)
        end
      end

      documents.map do |document|
        should_be_excluded?(document.doc_type)
        document.marshal_dump.slice(
          :document_id, :doc_type, :type_description, :received_at
        )
      end
    end

    def get_document(document_id)
      verify_document_in_folder(document_id)

      @client.send_request(
        VBMS::Requests::GetDocumentContent.new(document_id)
      ).content
    end

    private

    def should_be_excluded?(doc_type)
      raise Common::Exceptions::InvalidFieldValue('included_doc_types', doc_type) if EXCLUDED_DOC_TYPES.include?(doc_type)
    end

    def verify_document_in_folder(document_id)
      raise Common::Exceptions::Unauthorized unless list_documents.any? do |document|
        should_be_excluded?(document[:doc_type])
        document[:document_id] == document_id
      end
    end
  end
end
