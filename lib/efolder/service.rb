# frozen_string_literal: true

module Efolder
  ## Veteran Facing eFolder
  #
  # This service provides the veteran with methods to
  # both view the contents of their eFolder, and
  # also download the files contained therein.
  #

  class Service
    def initialize(user)
      @user = user
      @client = VBMS::Client.from_env_vars(env_name: Settings.vbms.env)
      @bgs_doc_uuids = bgs_doc_uuids
    end

    def list_documents
      vbms_docs.map do |document|
        if @bgs_doc_uuids.include?(document[:document_id].delete('{}'))
          document.marshal_dump.slice(
            :document_id, :doc_type, :type_description, :received_at
          )
        end
      end.compact
    end

    def get_document(document_id)
      verify_document_in_folder(document_id)

      @client.send_request(
        VBMS::Requests::GetDocumentContent.new(document_id)
      ).content
    end

    private

    def vbms_docs
      @client.send_request(
        VBMS::Requests::FindDocumentVersionReference.new(file_number)
      )
    end

    def file_number
      bgs_file_number = BGS::PeopleService.new(@user).find_person_by_participant_id[:file_nbr]
      bgs_file_number.empty? ? @user.ssn : bgs_file_number
    end

    def bgs_doc_uuids
      uuids = []
      BGS::UploadedDocumentService
        .new(@user)
        .get_documents
        .each do |claim|
          uploaded_docs = claim[:uplded_dcmnts]
          if uploaded_docs.is_a?(Hash)
            uuids << uploaded_docs[:uuid_txt]
          else
            uploaded_docs.each do |doc|
              uuids << doc[:uuid_txt]
            end
          end
        end
      uuids.compact
    end

    def verify_document_in_folder(document_id)
      raise Common::Exceptions::Unauthorized unless list_documents.any? do |document|
        document[:document_id] == document_id
      end
    end
  end
end
