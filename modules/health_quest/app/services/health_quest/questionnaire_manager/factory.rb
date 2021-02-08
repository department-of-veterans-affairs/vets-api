# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # A service object for isolating dependencies from the questionnaire_manager controller.
    # An aggregator which collects and combines data from the health_quest services, those which
    # interact with appointments and patient generated data in particular.
    #
    # @!attribute appointments
    #   @return [Array]
    # @!attribute aggregated_data
    #   @return [Hash]
    # @!attribute patient
    #   @return [FHIR::Patient]
    # @!attribute questionnaires
    #   @return [Array]
    # @!attribute appointment_service
    #   @return [HealthQuest::AppointmentService]
    # @!attribute patient_service
    #   @return [PatientGeneratedData::Patient::Factory]
    # @!attribute user
    # @!attribute questionnaire_service
    #   @return [PatientGeneratedData::Questionnaire::Factory]
    # @!attribute transformer
    #   @return [HealthQuest::QuestionnaireManager::Transformer]
    # @!attribute user
    #   @return [User]
    class Factory
      HEALTH_CARE_FORM_PREFIX = 'HC-QSTNR'

      attr_reader :appointments,
                  :aggregated_data,
                  :patient,
                  :questionnaires,
                  :questionnaire_responses,
                  :save_in_progress,
                  :appointment_service,
                  :patient_service,
                  :questionnaire_response_service,
                  :questionnaire_service,
                  :sip_model,
                  :transformer,
                  :user

      ##
      # Builds a HealthQuest::QuestionnaireManager::Factory instance from a user.
      #
      # @param user [User] the logged in user.
      # @return [HealthQuest::QuestionnaireManager::Factory] an instance of this class
      #
      def self.manufacture(user)
        new(user)
      end

      def initialize(user)
        @aggregated_data = default_response
        @user = user
        @appointment_service = AppointmentService.new(user)
        @patient_service = PatientGeneratedData::Patient::Factory.manufacture(user)
        @questionnaire_service = PatientGeneratedData::Questionnaire::Factory.manufacture(user)
        @questionnaire_response_service = PatientGeneratedData::QuestionnaireResponse::Factory.manufacture(user)
        @sip_model = InProgressForm
        @transformer = Transformer.build
      end

      ##
      # Interacts with and invokes functionality on the PGD and appointment health_quest services.
      # Invokes the `compose` method in the end to stitch all the data together for the controller.
      #
      # @return [Hash] an aggregated hash
      #
      def all
        @patient = get_patient.resource
        return default_response if patient.blank?

        @appointments = get_appointments[:data]
        return default_response if appointments.blank?

        @questionnaires = get_questionnaires.resource&.entry
        return default_response if questionnaires.blank?

        @questionnaire_responses = get_questionnaire_responses.resource&.entry
        @save_in_progress = get_save_in_progress

        compose
      end

      ##
      # Gets a patient resource from the PGD.
      #
      # @return [FHIR::Patient::ClientReply] an instance of ClientReply
      #
      def get_patient
        @get_patient ||= patient_service.get
      end

      ##
      # Gets a patients appointments by a default date range.
      #
      # @return [Hash] a hash containing appointment data and meta data
      #
      def get_appointments
        @get_appointments ||= appointment_service.get_appointments(three_months_ago, one_year_from_now)
      end

      ##
      # Gets a list of Questionnaires from the PGD.
      #
      # @return [FHIR::Bundle] an object containing the
      # entries for FHIR::Questionnaire objects
      #
      def get_questionnaires
        @get_questionnaires ||= begin
          use_context = transformer.get_use_context(appointments)

          questionnaire_service.search('context-type-value': use_context)
        end
      end

      ##
      # Gets a list of QuestionnaireResponses from the PGD.
      #
      # @return [FHIR::Bundle] an object containing the
      # entries for FHIR::QuestionnaireResponse objects
      #
      def get_questionnaire_responses
        @get_questionnaire_responses ||=
          questionnaire_response_service.search(
            source: user.icn,
            authored: [date_three_months_ago, date_one_year_from_now]
          )
      end

      # Gets a list of save in progress forms by the logged in user and a form prefix.
      #
      # @return [Array] an array containing the InProgressForm active record objects.
      #
      def get_save_in_progress
        sip_model
          .select(:form_id)
          .where('form_id LIKE ?', "%#{HEALTH_CARE_FORM_PREFIX}%")
          .where(user_uuid: user.uuid)
          .to_a
      end

      ##
      # Calls the `combine` transformer object method and passes the appointment,
      # questionnaire_response, questionnaire and SIP data as key/value arguments.
      #
      # @return [Hash] the final aggregated data structure for the UI/FE
      #
      def compose
        @compose ||= begin
          @aggregated_data = transformer.combine(
            appointments: appointments,
            questionnaires: questionnaires,
            questionnaire_responses: questionnaire_responses
          )
        end
      end

      private

      def date_three_months_ago
        (DateTime.now.in_time_zone.to_date - 3.months).to_s
      end

      def date_one_year_from_now
        (DateTime.now.in_time_zone.to_date + 12.months).to_s
      end

      def three_months_ago
        3.months.ago.in_time_zone
      end

      def one_year_from_now
        1.year.from_now.in_time_zone
      end

      def default_response
        { data: [] }
      end
    end
  end
end
