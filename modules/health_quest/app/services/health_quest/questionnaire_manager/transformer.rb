# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for mixing and blending data for the QuestionnaireManager::Factory
    # The method implementations are intentionally imperative as to make the data
    # blending process transparent and highlight the design considerations taken
    # to reduce time complexity.
    #
    # @!attribute appointments
    #   @return [Array]
    # @!attribute questionnaires
    #   @return [Array]
    # @!attribute questionnaire_responses
    #   @return [Array]
    # @!attribute save_in_progress
    #   @return [Array]
    # @!attribute hashed_questionnaires
    #   @return [Hash]
    # @!attribute hashed_questionnaire_responses
    #   @return [Hash]
    # @!attribute hashed_save_in_progress
    #   @return [Hash]
    class Transformer
      IN_PROGRESS_STATUS = 'in-progress'
      QR_APPOINTMENT_ID_MATCHER = /([I2\-a-zA-Z0-9]+)\z/i.freeze
      SIP_APPOINTMENT_ID_MATCHER = /HC-QSTNR_([I2\-a-zA-Z0-9]+)_/i.freeze
      SIP_QUESTIONNAIRE_ID_MATCHER = /_([a-f0-9-]+)\z/i.freeze

      attr_reader :appointments,
                  :questionnaires,
                  :questionnaire_responses,
                  :save_in_progress,
                  :hashed_questionnaires,
                  :hashed_questionnaire_responses,
                  :hashed_save_in_progress

      ##
      # Builds a HealthQuest::QuestionnaireManager::Transformer instance
      #
      # @param user [Hash] the set of data to be used to construct the Questionnaire Manager data.
      # @return [HealthQuest::QuestionnaireManager::Transformer] an instance of this class
      #
      def self.manufacture(opts = {})
        new(opts)
      end

      def initialize(opts)
        @appointments = opts[:appointments]
        @questionnaires = opts[:questionnaires]
        @questionnaire_responses = opts[:questionnaire_responses]
        @save_in_progress = opts[:save_in_progress]
        @hashed_questionnaires = questionnaires_with_facility_clinic_id
        @hashed_questionnaire_responses = questionnaire_responses_with_appointment_id
        @hashed_save_in_progress = sip_with_appointment_id
      end

      ##
      # Builds the final aggregated data structure from a set of optimized data structures:
      # `appointments`, `hashed_questionnaires`, `hashed_questionnaire_responses`,
      # and `hashed_save_in_progress`.
      #
      # @return [Hash] a combined hash containing appointment, questionnaire_response,
      # questionnaire and SIP data
      #
      def combine # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        questionnaire_manager_data =
          appointments_with_questionnaires.each_with_object([]) do |item, accumulator|
            appointment_id = item[:appointment][:id]
            qr_responses = hashed_questionnaire_responses[appointment_id]
            sip_responses = hashed_save_in_progress[appointment_id]

            return { data: appointments_with_questionnaires } if qr_responses.blank? && sip_responses.blank?

            appointment_questionnaires =
              item[:questionnaire].each_with_object({}) do |appointment_questionnaire, acc|
                questionnaire_id = appointment_questionnaire[:id]
                acc[questionnaire_id] = appointment_questionnaire
              end

            qr_responses&.each do |qr|
              questionnaire_id = qr.resource.id
              questionnaire = appointment_questionnaires[questionnaire_id]
              next if questionnaire.blank?

              questionnaire[:questionnaire_response].store(:id, qr.resource.id)
              questionnaire[:questionnaire_response].store(:status, qr.resource.status)
              questionnaire[:questionnaire_response].store(:submitted_on, qr.resource.authored)
            end

            sip_responses&.each do |sip|
              sip_questionnaire_id = sip.form_id.match(SIP_QUESTIONNAIRE_ID_MATCHER)[1]
              questionnaire = appointment_questionnaires[sip_questionnaire_id]
              next if questionnaire.blank?

              questionnaire[:questionnaire_response].store(:status, IN_PROGRESS_STATUS)
            end

            accumulator << item
          end

        { data: questionnaire_manager_data }
      end

      private

      def appointments_with_questionnaires
        @appointments_with_questionnaires ||=
          appointments.each_with_object([]) do |appointment, accumulator|
            context_key = "#{appointment.facility_id}/#{appointment.clinic_id}"

            next unless hashed_questionnaires.key?(context_key)

            questionnaires =
              hashed_questionnaires[context_key].map do |quest|
                { id: quest.resource.id, title: quest.resource.title, questionnaire_response: {} }
              end
            appointment_questionnaire = { appointment: appointment.to_h, questionnaire: questionnaires }

            accumulator << appointment_questionnaire
          end
      end

      def sip_with_appointment_id
        @sip_with_appointment_id ||=
          save_in_progress.each_with_object({}) do |sip, accumulator|
            appointment_id = sip.form_id.match(SIP_APPOINTMENT_ID_MATCHER)[1]

            if accumulator.key?(appointment_id)
              accumulator[appointment_id] << sip
            else
              accumulator[appointment_id] = [sip]
            end
          end
      end

      def questionnaires_with_facility_clinic_id
        @questionnaires_with_facility_clinic_id ||=
          questionnaires.each_with_object({}) do |questionnaire, accumulator|
            questionnaire_hash = questionnaire.to_hash
            use_contexts = questionnaire_hash['resource']['useContext']
            value_codeable_concepts = use_contexts.map { |c| c['valueCodeableConcept']['coding'] }.flatten
            codes = value_codeable_concepts.map { |vcc| vcc['code'] }

            codes.each do |code|
              if accumulator.key?(code)
                accumulator[code] << questionnaire
              else
                accumulator[code] = [questionnaire]
              end
            end
          end
      end

      def questionnaire_responses_with_appointment_id
        @questionnaire_responses_with_appointment_id ||=
          questionnaire_responses.each_with_object({}) do |questionnaire_response, accumulator|
            appointment_reference = questionnaire_response.subject.reference
            appointment_id = appointment_reference.match(QR_APPOINTMENT_ID_MATCHER)[1]

            if accumulator.key?(appointment_id)
              accumulator[appointment_id] << questionnaire_response
            else
              accumulator[appointment_id] = [questionnaire_response]
            end
          end
      end
    end
  end
end
