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
      #   @return [FHIR::Patient]
      # @!attribute identifier
      #   @return [FHIR::Identifier]
      # @!attribute meta
      #   @return [FHIR::Meta]
      # @!attribute data
      #   @return [Hash]
      # @!attribute source_reference
      #   @return [FHIR::Reference]
      # @!attribute subject_reference
      #   @return [FHIR::Reference]
      class Resource
        include Shared::IdentityMetaInfo
        ##
        # Set the QuestionnaireResponse's status
        #
        COMPLETED_STATUS = 'completed'
        ##
        # Set the default Questionnaire ID
        #
        DEFAULT_QUESTIONNAIRE_ID = '1776c749-91b8-4f33-bece-a5a72f3bb09b'
        ##
        # Set the default Questionnaire Title if one is not present
        #
        DEFAULT_QUESTIONNAIRE_TITLE = 'Pre-Visit Questionnaire'

        attr_reader :user,
                    :model,
                    :identifier,
                    :meta,
                    :data,
                    :source_reference,
                    :subject_reference

        ##
        # Builds a HealthApi::Patient::Resource instance from a given User
        #
        # @param data [Hash] questionnaire answers and appointment data hash.
        # @param user [User] the currently logged in user.
        # @return [HealthApi::Patient::Resource] an instance of this class
        #
        def self.manufacture(data, user)
          new(data, user)
        end

        def initialize(data, user)
          @model = FHIR::QuestionnaireResponse.new
          @data = data
          @user = user
          @identifier = FHIR::Identifier.new
          @meta = FHIR::Meta.new
          @source_reference = FHIR::Reference.new
          @subject_reference = FHIR::Reference.new
        end

        ##
        # Builds the FHIR::QuestionnaireResponse object for the PGD.
        #
        # @return [FHIR::QuestionnaireResponse]
        #
        def prepare
          model.tap do |p|
            p.authored = set_date
            p.identifier = set_identifiers
            p.item = set_item
            p.meta = set_meta
            p.questionnaire = set_questionnaire
            p.source = set_source
            p.subject = set_subject
            p.status = set_status
            p.text = set_text
          end
        end

        ##
        # Builds the text hash attribute for the FHIR::QuestionnaireResponse object.
        #
        # @return [Hash] text information
        #
        def set_text
          {
            status: 'generated',
            div: "<div><h1>#{questionnaire_title}</h1></div>"
          }
        end

        ##
        # Builds the subject reference.
        #
        # @return [FHIR::Reference]
        #
        def set_subject
          appointment_id = data.dig(:appointment, :id)
          subject_reference.reference = "#{health_api_url_path}/Appointment/#{appointment_id}"
          subject_reference
        end

        ##
        # Builds the source reference.
        #
        # @return [FHIR::Reference]
        #
        def set_source
          source_reference.reference = "#{health_api_url_path}/Patient/#{user.icn}"
          source_reference
        end

        ##
        # Builds the questionnaire id.
        #
        # @return [String]
        #
        def set_questionnaire
          questionnaire_id = data.dig(:questionnaire, :id) || DEFAULT_QUESTIONNAIRE_ID

          "Questionnaire/#{questionnaire_id}"
        end

        ##
        # Builds the item array attribute for the FHIR::QuestionnaireResponse object.
        #
        # @return [Array]
        #
        def set_item
          data[:item]
        end

        ##
        # Returns the questionnaire's title.
        #
        # @return [String]
        #
        def questionnaire_title
          data.dig(:questionnaire, :title) || DEFAULT_QUESTIONNAIRE_TITLE
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
        # Returns the completed status.
        #
        # @return [String]
        #
        def set_status
          COMPLETED_STATUS
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

        private

        def health_api_url_path
          url = Settings.hqva_mobile.lighthouse.url
          health_api_path = Settings.hqva_mobile.lighthouse.health_api_path

          "#{url}#{health_api_path}"
        end
      end
    end
  end
end
