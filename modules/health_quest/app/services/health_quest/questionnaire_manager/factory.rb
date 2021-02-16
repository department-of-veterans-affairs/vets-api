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
    # @!attribute questionnaire_responses
    #   @return [Array]
    # @!attribute save_in_progress
    #   @return [Array]
    # @!attribute appointment_service
    #   @return [HealthQuest::AppointmentService]
    # @!attribute patient_service
    #   @return [HealthApi::Patient::Factory]
    # @!attribute questionnaire_response_service
    #   @return [PatientGeneratedData::QuestionnaireResponse::Factory]
    # @!attribute user
    # @!attribute questionnaire_service
    #   @return [PatientGeneratedData::Questionnaire::Factory]
    # @!attribute sip_model
    #   @return [InProgressForm]
    # @!attribute transformer
    #   @return [HealthQuest::QuestionnaireManager::Transformer]
    # @!attribute user
    #   @return [User]
    class Factory
      HEALTH_CARE_FORM_PREFIX = 'HC-QSTNR'
      USE_CONTEXT_DELIMITER = ','

      attr_reader :appointments,
                  :aggregated_data,
                  :patient,
                  :questionnaires,
                  :questionnaire_responses,
                  :request_threads,
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
        @patient_service = HealthApi::Patient::Factory.manufacture(user)
        @questionnaire_service = PatientGeneratedData::Questionnaire::Factory.manufacture(user)
        @questionnaire_response_service = PatientGeneratedData::QuestionnaireResponse::Factory.manufacture(user)
        @request_threads = []
        @sip_model = InProgressForm
        @transformer = Transformer
      end

      ##
      # Interacts with and invokes functionality on the PGD and appointment health_quest services.
      # Invokes the `compose` method in the end to stitch all the data together for the controller.
      #
      # @return [Hash] an aggregated hash
      #
      def all
        @appointments = get_appointments[:data]
        return default_response if appointments.blank?

        concurrent_pgd_requests
        return default_response if patient.blank? || questionnaires.blank?

        compose
      end

      ##
      # Multi-Threaded and independent requests to the PGD and vets-api to cut down on network call times.
      # Sets the patient, questionnaires, questionnaire_responses and save_in_progress instance variables
      # independently by calling the separate endpoints through different threads. Any exception raised
      # during the execution of a thread will abort the current set of threads and bubble up the exception
      # to the main thread as well as return execution to it.
      #
      # @return [Array] an array of dead threads that have finished executing their tasks
      #
      def concurrent_pgd_requests
        Thread.abort_on_exception = true

        # rubocop:disable ThreadSafety/NewThread
        request_threads << Thread.new { @patient = get_patient.resource }
        request_threads << Thread.new { @questionnaires = get_questionnaires.resource&.entry }
        request_threads << Thread.new { @questionnaire_responses = get_questionnaire_responses.resource&.entry }
        request_threads << Thread.new { @save_in_progress = get_save_in_progress }
        # rubocop:enable ThreadSafety/NewThread

        request_threads.each(&:join)
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
          questionnaire_service.search('context-type-value': get_use_context)
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
          @aggregated_data = transformer.manufacture(
            appointments: appointments,
            questionnaires: questionnaires,
            questionnaire_responses: questionnaire_responses,
            save_in_progress: save_in_progress
          )

          aggregated_data.combine
        end
      end

      ##
      # Builds the use context string from a list of appointments
      #
      # @return [String] a context-type-value built using facility and clinic IDs
      #
      def get_use_context
        use_context_array =
          appointments.each_with_object([]) do |apt, accumulator|
            key_with_venue = "venue$#{apt.facility_id}/#{apt.clinic_id}"

            accumulator << key_with_venue
          end

        use_context_array.join(USE_CONTEXT_DELIMITER)
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
