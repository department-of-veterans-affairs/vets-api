# frozen_string_literal: true

require_relative 'base'

module CARMA
  module Models
    class Attachment < Base
      DOCUMENT_TYPES = { '10-10CG' => '10-10CG', 'POA' => 'POA' }.freeze

      attr_accessor   :carma_case_id,
                      :veteran_name,
                      :file_path,
                      :document_type,
                      :document_date,
                      :id

      def initialize(args = {})
        # TODO: We should select a timezone based on the claim's planned facility.
        timezone = 'Eastern Time (US & Canada)'

        @carma_case_id  = args[:carma_case_id]
        @veteran_name   = args[:veteran_name]
        @file_path      = args[:file_path]
        @document_type  = args[:document_type]
        @document_date  = args[:document_date] || Time.now.in_time_zone(timezone).to_date
        @id             = args[:id]
      end

      def title
        [
          document_type,
          veteran_name[:first],
          veteran_name[:last],
          document_date.strftime('%m-%d-%Y')
        ].join('_')
      end

      def reference_id
        document_type.delete('-')
      end

      def to_request_payload
        {
          'attributes' => {

            # property:   attributes.type
            # value:      'ContentVersion'
            # comments:   Static String to reference the target object in salesforce for Files.
            # examples:   'ContentVersion'
            'type' => 'ContentVersion',

            # property:   attributes.referenceId
            # value:      Any unique string that maps to the file that is posted.
            # comments:   A string that will be returned in the response that can be correlated
            #             to the salesforce unique id of the created file. This is not persisted in salesforce.
            # examples:   '1010CG' | 'POA'
            'referenceId' => reference_id
          },

          # property:   Title
          # value:      Formatted file name that shows up in Salesforce
          # comments:   The expected format is:
          #             <CARMA_Document_Type__c>_<VeteranFirstName>_<VeteranLastName>_<SubmittedDateMM-DD-YYYY>
          #               1.  <CARMA_Document_Type__c> - Type litral for the document valid values are
          #                 '10-10CG' for the online application and 'POA' for Power of attorney
          #               2.  <VeteranFirstName> - First Name of the Veteran.
          # examples:   '10-10CG_John_Doe_03-30-2020' | 'POA_John_Doe_03-30-2020'
          'Title' => title,

          # property:   PathOnClient
          # value:      Name of the pdf file uploaded with file extension.
          # comments:   The actual file pdf file name.
          # examples:   'filename.pdf'
          # 'PathOnClient' => file_path,
          'PathOnClient' => file_path.split('/').last,

          # property:   CARMA_Document_Type__c
          # value:      Static string literal for the type of the document.
          # comments:   Accepted values are '10-10CG' for the online application and 'POA'
          #             for Power of attorney document.
          # examples:   '10-10CG' | 'POA'
          'CARMA_Document_Type__c' => document_type,

          # property:   CARMA_Document_Date__c
          # value:      Date when the document is uploaded.
          # comments:   Date the file was submitted in the format YYYY-MM-DD
          # examples:   '2020-03-30'
          'CARMA_Document_Date__c' => document_date.strftime('%Y-%m-%d'),

          # property:   FirstPublishLocationId
          # value:      The carmacase.id that was returned during a successful application creation.
          # comments:   18 character salesforce id returned in the application submission
          #             service call response(carmacase.id).
          # examples:   'aB9r00000004GW9CAK'
          'FirstPublishLocationId' => carma_case_id,

          # property:   VersionData
          # value:      The base64 encoded binary of the pdf file content.
          # comments:   The base64 encoded binary of the pdf file content.
          #             service call response(carmacase.id).
          # examples:   'JVBERi0xLjMKJcTl8uXrp<.....rest of the base64 ecoded pdf file content>'
          'VersionData' => as_base64
        }
      end

      def to_hash
        {
          id:,
          carma_case_id:,
          veteran_name:,
          file_path:,
          document_type:,
          document_date:
        }
      end

      private

      def as_base64
        Base64.encode64(
          File.read(
            file_path
          )
        )
      end
    end
  end
end
