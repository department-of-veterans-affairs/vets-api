# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module PayloadBuilder
      class InquiryPayload
        include SharedHelpers

        class InquiryPayloadError < StandardError; end
        attr_reader :inquiry_params, :inquiry_details, :submitter_profile, :user, :veteran_profile

        UNAUTHENTICATE_ID = '722310000'
        INQUIRY_SOURCE_AVA_ID = '722310000'

        def initialize(inquiry_params:, user: nil)
          @inquiry_params = inquiry_params
          validate_params!
          @inquiry_details = InquiryDetails.new(inquiry_params).call
          @user = user
          @submitter_profile = SubmitterProfile.new(inquiry_params:, user:, inquiry_details:)
          @veteran_profile = VeteranProfile.new(inquiry_params:, inquiry_details:)
          @translator = Translator.new
        end

        def call
          payload = {
            AreYouTheDependent: dependent_of_veteran?,
            AttachmentPresent: attachment_present?,
            CaregiverZipCode: nil,
            ContactMethod: @translator.call(:response_type, inquiry_params[:contact_preference]),
            DependentDOB: family_member_field(:date_of_birth),
            DependentFirstName: family_member_field(:first)
          }.merge(additional_payload_fields)

          payload[:LevelOfAuthentication] = UNAUTHENTICATE_ID if user.nil?

          payload
        end

        private

        def additional_payload_fields
          {
            DependentLastName: family_member_field(:last),
            DependentMiddleName: family_member_field(:middle),
            DependentRelationship: translate_field(:dependent_relationship),
            DependentSSN: family_member_field(:ssn),
            InquiryAbout: translate_field(:inquiry_about),
            InquiryCategory: inquiry_params[:category_id],
            InquirySource: INQUIRY_SOURCE_AVA_ID,
            InquirySubtopic: inquiry_params[:subtopic_id],
            InquirySummary: inquiry_params[:subject],
            InquiryTopic: inquiry_params[:topic_id],
            IsVeteranDeceased: inquiry_params[:is_veteran_deceased]
          }.merge(school_state_and_profile_data)
        end

        def school_state_and_profile_data
          {
            LevelOfAuthentication: translate_field(:level_of_authentication),
            MedicalCenter: inquiry_params[:your_health_facility],
            SchoolObj: build_school_object,
            SubmitterQuestion: inquiry_params[:question],
            SubmitterStateOfSchool: build_state_data(:school_obj, :state_abbreviation),
            SubmitterStateProperty: build_state_data(:address, :state),
            SubmitterStateOfResidency: build_residency_state_data,
            SubmitterZipCodeOfResidency: inquiry_params[:postal_code],
            UntrustedFlag: nil,
            VeteranDateOfDeath: inquiry_params[:date_of_death],
            VeteranRelationship: translate_field(:veteran_relationship),
            WhoWasTheirCounselor: counselor_info,
            ListOfAttachments: list_of_attachments,
            SubmitterProfile: submitter_profile.call,
            VeteranProfile: veteran_profile.call
          }
        end

        def validate_params!
          raise InquiryPayloadError, 'Missing required inquiry parameters' if inquiry_params.nil?
        end

        def attachment_present?
          !list_of_attachments.nil?
        end

        def list_of_attachments
          return if inquiry_params[:files].first[:file_name].nil?

          inquiry_params[:files].map do |file|
            { FileName: file[:file_name], FileContent: file[:base64] }
          end
        end

        def build_school_object
          {
            City: nil,
            InstitutionName: inquiry_params[:school_obj]&.dig(:institution_name),
            SchoolFacilityCode: inquiry_params[:school_obj]&.dig(:school_facility_code),
            StateAbbreviation: inquiry_params[:school_obj]&.dig(:state_abbreviation),
            RegionalOffice: nil
          }
        end

        def family_member_field(field)
          inquiry_params.dig(:about_the_family_member, field)
        end

        def translate_field(key)
          @translator.call(key, inquiry_details[key])
        end

        def counselor_info
          inquiry_params[:their_vre_couselor] || inquiry_params[:your_vre_counselor]
        end

        def build_residency_state_data
          {
            Name: inquiry_params.dig(:state_or_residency, :residency_state),
            StateCode: fetch_state_code(inquiry_params.dig(:state_or_residency, :residency_state))
          }
        end

        def property_state_data
          {
            Name: fetch_state(inquiry_params.dig(:address, :state)),
            StateCode: inquiry_params.dig(:address, :state)
          }
        end

        def build_state_data(obj, key)
          {
            Name: fetch_state(inquiry_params.dig(obj, key)),
            StateCode: inquiry_params.dig(obj, key)
          }
        end

        def dependent_of_veteran?
          inquiry_params[:who_is_your_question_about] == 'Myself' &&
            inquiry_params[:relationship_to_veteran] == "I'm a family member of a Veteran"
        end
      end
    end
  end
end
