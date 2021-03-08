# frozen_string_literal: true

module HealthQuest
  module Resource
    module ClientModel
      class QuestionnaireResponse
        include Shared::IdentityMetaInfo

        COMPLETED_STATUS = 'completed'
        DEFAULT_QUESTIONNAIRE_ID = '1776c749-91b8-4f33-bece-a5a72f3bb09b'
        DEFAULT_QUESTIONNAIRE_TITLE = 'Pre-Visit Questionnaire'

        attr_reader :user,
                    :model,
                    :identifier,
                    :meta,
                    :data,
                    :source_reference,
                    :subject_reference

        def self.manufacture(data, user)
          new(data, user)
        end

        def initialize(data, user)
          @model = ::FHIR::QuestionnaireResponse.new
          @data = data
          @user = user
          @identifier = ::FHIR::Identifier.new
          @meta = ::FHIR::Meta.new
          @source_reference = ::FHIR::Reference.new
          @subject_reference = ::FHIR::Reference.new
        end

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

        def set_text
          {
            status: 'generated',
            div: "<div><h1>#{questionnaire_title}</h1></div>"
          }
        end

        def set_subject
          appointment_id = data.dig(:appointment, :id)
          subject_reference.reference = "#{health_api_url_path}/Appointment/#{appointment_id}"
          subject_reference
        end

        def set_source
          source_reference.reference = "#{health_api_url_path}/Patient/#{user.icn}"
          source_reference
        end

        def set_questionnaire
          questionnaire_id = data.dig(:questionnaire, :id) || DEFAULT_QUESTIONNAIRE_ID

          "Questionnaire/#{questionnaire_id}"
        end

        def set_item
          data[:item]
        end

        def questionnaire_title
          data.dig(:questionnaire, :title) || DEFAULT_QUESTIONNAIRE_TITLE
        end

        def set_date
          Time.zone.today.to_s
        end

        def set_status
          COMPLETED_STATUS
        end

        def identifier_value
          DEFAULT_QUESTIONNAIRE_ID
        end

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
