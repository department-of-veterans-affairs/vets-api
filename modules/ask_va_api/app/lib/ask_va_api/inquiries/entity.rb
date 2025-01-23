# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class Entity
      attr_reader :id,
                  :inquiry_number,
                  :attachments,
                  :category_name,
                  :created_on,
                  :correspondences,
                  :has_been_split,
                  :inquiry_topic,
                  :level_of_authentication,
                  :last_update,
                  :queue_id,
                  :queue_name,
                  :status,
                  :submitter_question,
                  :school_facility_code,
                  :veteran_relationship,
                  :allow_attachments,
                  :allow_replies,
                  :has_attachments

      def initialize(info, correspondences = nil)
        @id = info[:Id]
        @allow_attachments = info[:AllowAttachments]
        @allow_replies = info[:AllowReplies]
        @has_attachments = info[:InquiryHasAttachments]
        @inquiry_number = info[:InquiryNumber]
        @attachments = info[:AttachmentNames]
        @category_name = info[:CategoryName]
        @created_on = info[:CreatedOn]
        @correspondences = correspondences
        @has_been_split = info[:InquiryHasBeenSplit]
        @inquiry_topic = info[:InquiryTopic]
        @level_of_authentication = info[:InquiryLevelOfAuthentication]
        @last_update = info[:LastUpdate]
        @queue_id = info[:QueueId]
        @queue_name = info[:QueueName]
        @status = info[:InquiryStatus]
        @school_facility_code = info[:SchoolFacilityCode]
        @submitter_question = info[:SubmitterQuestion]
        @veteran_relationship = info[:VeteranRelationship]
      end
    end
  end
end
