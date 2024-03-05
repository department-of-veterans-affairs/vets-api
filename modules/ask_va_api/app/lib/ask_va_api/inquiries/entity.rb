# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class Entity
      attr_reader :id,
                  :inquiry_number,
                  :attachments,
                  :correspondences,
                  :has_attachments,
                  :has_been_split,
                  :level_of_authentication,
                  :last_update,
                  :status,
                  :submitter_question,
                  :school_facility_code,
                  :topic,
                  :veteran_relationship

      def initialize(info, correspondences = nil)
        @id = info[:Id]
        @inquiry_number = info[:InquiryNumber]
        @attachments = info[:AttachmentNames]
        @correspondences = correspondences
        @has_attachments = info[:InquiryHasAttachments]
        @has_been_split = info[:InquiryHasBeenSplit]
        @level_of_authentication = info[:InquiryLevelOfAuthentication]
        @last_update = info[:LastUpdate]
        @status = info[:InquiryStatus]
        @school_facility_code = info[:SchoolFacilityCode]
        @submitter_question = info[:SubmitterQuestion]
        @topic = info[:InquiryTopic]
        @veteran_relationship = info[:VeteranRelationship]
      end
    end
  end
end
