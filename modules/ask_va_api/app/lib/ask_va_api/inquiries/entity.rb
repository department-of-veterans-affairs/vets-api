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
        @id = info[:id]
        @inquiry_number = info[:inquiryNumber]
        @attachments = info[:attachmentNames]
        @correspondences = correspondences
        @has_attachments = info[:inquiryHasAttachments]
        @has_been_split = info[:inquiryHasBeenSplit]
        @level_of_authentication = info[:inquiryLevelOfAuthentication]
        @last_update = info[:lastUpdate]
        @status = info[:inquiryStatus]
        @school_facility_code = info[:schoolFacilityCode]
        @submitter_question = info[:submitterQuestion]
        @topic = info[:inquiryTopic]
        @veteran_relationship = info[:veteranRelationship]
      end
    end
  end
end
