# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module QuestionnaireResponse
      ##
      # An object for generating a FHIR QuestionnaireResponse resource for the PGD.
      #
      # @!attribute user
      #   @return [User]
      # @!attribute model
      #   @return [FHIR::DSTU2::Patient]
      # @!attribute identifier
      #   @return [FHIR::DSTU2::Identifier]
      # @!attribute meta
      #   @return [FHIR::DSTU2::Meta]
      # @!attribute data
      #   @return [Hash]
      # @!attribute author_reference
      #   @return [FHIR::DSTU2::Reference]
      # @!attribute questionnaire_reference
      #   @return [FHIR::DSTU2::Reference]
      class Resource
        include PatientGeneratedData::Common::IdentityMetaInfo
        ##
        # Set the QuestionnaireResponse's status
        #
        COMPLETED_STATUS = 'completed'
        ##
        # Set the QuestionnaireResponse's subject use
        #
        SUBJECT_USE = 'usual'
        ##
        # Set the default Questionnaire ID
        #
        DEFAULT_QUESTIONNAIRE_ID = '1776c749-91b8-4f33-bece-a5a72f3bb09b'

        attr_reader :user, :model, :identifier, :meta, :data, :author_reference, :questionnaire_reference

        ##
        # Builds a PatientGeneratedData::Patient::Resource instance from a given User
        #
        # @param data [Hash] questionnaire answers and appointment data hash.
        # @param user [User] the currently logged in user.
        # @return [PatientGeneratedData::Patient::Resource] an instance of this class
        #
        def self.manufacture(data, user)
          new(data, user)
        end

        def initialize(data, user)
          @model = FHIR::DSTU2::QuestionnaireResponse.new
          @data = data
          @user = user
          @identifier = FHIR::DSTU2::Identifier.new
          @meta = FHIR::DSTU2::Meta.new
          @author_reference = FHIR::DSTU2::Reference.new
          @questionnaire_reference = FHIR::DSTU2::Reference.new
        end

        ##
        # Builds the FHIR::DSTU2::QuestionnaireResponse object for the PGD.
        #
        # @return [FHIR::DSTU2::QuestionnaireResponse]
        #
        def prepare
          model.tap do |p|
            p.identifier = set_identifiers
            p.meta = set_meta
            p.text = set_text
            p.status = COMPLETED_STATUS
            p.authored = set_date
            p.author = set_author
            p.subject = set_subject
            p.questionnaire = set_questionnaire
            p.group = set_group
          end
        end

        ##
        # Builds the text hash attribute for the FHIR::DSTU2::QuestionnaireResponse object.
        #
        # @return [Hash] text information
        #
        def set_text
          {
            status: 'generated',
            div: '<div><h1>Pre-Visit Questionnaire</h1></div>'
          }
        end

        ##
        # Sets the author reference for the FHIR::DSTU2::Reference object.
        #
        # @return [FHIR::DSTU2::Reference] a reference for the author
        #
        def set_author
          author_reference.reference = "Patient/#{user.icn}"
        end

        ##
        # Builds the subject hash attribute for the FHIR::DSTU2::QuestionnaireResponse object.
        #
        # @return [Hash] subject information
        #
        def set_subject
          url = Settings.hqva_mobile.url
          icn = user.icn
          appointment_id = data[:appointment_id]

          {
            use: SUBJECT_USE,
            value: "#{url}/appointments/v1/patients/#{icn}/Appointment/#{appointment_id}"
          }
        end

        ##
        # Sets the questionnaire reference for the FHIR::DSTU2::Reference object.
        #
        # @return [FHIR::DSTU2::Reference] a reference for the questionnaire
        #
        def set_questionnaire
          questionnaire_reference.reference = "Questionnaire/#{DEFAULT_QUESTIONNAIRE_ID}"
        end

        ##
        # Builds the group hash attribute for the FHIR::DSTU2::QuestionnaireResponse object.
        #
        # @return [Hash] group information
        #
        def set_group
          data[:group]
        end

        ##
        # Returns today's date.
        #
        # @return [String] today's date in String format
        #
        def set_date
          Time.zone.today.to_s
        end

        ##
        # Return the QuestionnaireResponse default ID.
        #
        # @return [String]
        #
        def identifier_value
          DEFAULT_QUESTIONNAIRE_ID
        end

        ##
        # Return the QuestionnaireResponse's identifier attribute name.
        #
        # @return [String]
        #
        def identifier_code
          'QuestionnaireResponseID'
        end
      end
    end
  end
end
