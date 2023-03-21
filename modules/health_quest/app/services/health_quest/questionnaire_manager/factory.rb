# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # A service object for isolating dependencies from the questionnaire_manager controller.
    # An aggregator which collects and combines data from the health_quest services, those which
    # interact with appointments and patient generated data in particular.
    #
    # @!attribute lighthouse_appointments
    #   @return [Array]
    # @!attribute locations
    #   @return [Array]
    # @!attribute organizations
    #   @return [Array]
    # @!attribute facilities
    #   @return [Array]
    # @!attribute aggregated_data
    #   @return [Hash]
    # @!attribute patient
    #   @return [FHIR::Patient]
    # @!attribute questionnaires
    #   @return [Array]
    # @!attribute questionnaire_response
    #   @return [HealthQuest::QuestionnaireResponse]
    # @!attribute questionnaire_responses
    #   @return [Array]
    # @!attribute save_in_progress
    #   @return [Array]
    # @!attribute lighthouse_appointment_service
    #   @return [HealthQuest::Resource::Factory]
    # @!attribute location_service
    #   @return [HealthQuest::Resource::Factory]
    # @!attribute organization_service
    #   @return [HealthQuest::Resource::Factory]
    # @!attribute patient_service
    #   @return [HealthQuest::Resource::Factory]
    # @!attribute questionnaire_response_service
    #   @return [HealthQuest::Resource::Factory]
    # @!attribute questionnaire_service
    #   @return [HealthQuest::Resource::Factory]
    # @!attribute facilities_request
    #   @return [HealthQuest::Facilities::Request]
    # @!attribute sip_model
    #   @return [InProgressForm]
    # @!attribute transformer
    #   @return [HealthQuest::QuestionnaireManager::Transformer]
    # @!attribute user
    #   @return [User]
    class Factory
      include FactoryTypes

      HEALTH_CARE_FORM_PREFIX = 'HC-QSTNR'
      USE_CONTEXT_DELIMITER = ','
      ID_MATCHER = /([I2\-a-zA-Z0-9]+)\z/i
      SUCCESS_STATUS = '201'

      attr_reader :lighthouse_appointments,
                  :locations,
                  :organizations,
                  :facilities,
                  :aggregated_data,
                  :patient,
                  :questionnaires,
                  :questionnaire_response,
                  :questionnaire_responses,
                  :request_threads,
                  :save_in_progress,
                  :appointment_service,
                  :lighthouse_appointment_service,
                  :location_service,
                  :organization_service,
                  :patient_service,
                  :questionnaire_response_service,
                  :questionnaire_service,
                  :facilities_request,
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
        @questionnaire_response = HealthQuest::QuestionnaireResponse.new
        @lighthouse_appointment_service = HealthQuest::Resource::Factory.manufacture(appointment_type)
        @location_service = HealthQuest::Resource::Factory.manufacture(location_type)
        @organization_service = HealthQuest::Resource::Factory.manufacture(organization_type)
        @patient_service = HealthQuest::Resource::Factory.manufacture(patient_type)
        @questionnaire_service = HealthQuest::Resource::Factory.manufacture(questionnaire_type)
        @questionnaire_response_service = HealthQuest::Resource::Factory.manufacture(questionnaire_response_type)
        @facilities_request = HealthQuest::Facilities::Request.build
        @request_threads = []
        @sip_model = InProgressForm
        @transformer = Transformer
      end

      ##
      # Interacts with and invokes functionality on FHIR PGD and Health API services.
      # Invokes the `compose` method in the end to stitch all the data together for the controller.
      #
      # @return [Hash] an aggregated hash
      #
      def all
        @lighthouse_appointments = get_lighthouse_appointments.resource&.entry
        @locations = get_locations

        return default_response if lighthouse_appointments.blank?

        concurrent_pgd_requests
        @facilities = get_facilities

        return default_response if patient.blank? || questionnaires.blank?

        compose
      end

      ##
      # Create a QuestionnaireResponse resource in the Lighthouse PGD.
      # If the resource creation is successful, then store an encrypted snapshot of
      # the User's demographics and the submitted answers to the Questionnaire so
      # that we can construct a PDF for the signed in Patient.
      #
      # @param data [Hash] questionnaire answers and appointment data hash.
      # @return [FHIR::ClientReply] an instance of ClientReply
      #
      def create_questionnaire_response(data)
        attrs = data.to_h.with_indifferent_access
        response = questionnaire_response_service.create(attrs)

        response.tap do |resp|
          if resp.response[:code] == SUCCESS_STATUS
            questionnaire_response.tap do |qr|
              qr.user_uuid = user.uuid
              qr.user_account = user.user_account
              qr.appointment_id = attrs.dig(:appointment, :id)
              qr.questionnaire_response_id = resp.resource.id
              qr.user = user
              qr.questionnaire_response_data = data

              qr.save
            end
          end
        end
      end

      ##
      # Factory method for generating a PDF document containing questions and answers
      # and demographics information filled out by the patient for a pre-visit questionnaire.
      # This will return the questionnaire_response_id string for the time being.
      #
      # @param questionnaire_response_id [String]
      # @return [String]
      #
      def generate_questionnaire_response_pdf(questionnaire_response_id)
        snapshot = HealthQuest::QuestionnaireResponse
                   .where(user_uuid: user.uuid, questionnaire_response_id: questionnaire_response_id.to_s)
                   .first
        appointment = lighthouse_appointment_service.get(snapshot.appointment_id)
        loc_id = appointment.resource.participant.first.actor.reference.match(ID_MATCHER)[1]
        location = location_service.get(loc_id)
        org_id = location.resource.managingOrganization.reference.match(ID_MATCHER)[1]
        org = organization_service.get(org_id)

        HealthQuest::QuestionnaireManager::PdfGenerator::Composer
          .synthesize(questionnaire_response: snapshot, appointment: appointment, location: location, org: org)
          .document
          .render
      end

      ##
      # Multi-Threaded and independent requests to the PGD, Health API, and vets-api to cut down on network overhead.
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
        request_threads << Thread.new { @organizations = get_organizations }
        request_threads << Thread.new { @questionnaires = get_questionnaires.resource&.entry }
        request_threads << Thread.new { @questionnaire_responses = get_questionnaire_responses.resource&.entry }
        request_threads << Thread.new { @save_in_progress = get_save_in_progress }
        # rubocop:enable ThreadSafety/NewThread

        request_threads.each(&:join)
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
            lighthouse_appointments: lighthouse_appointments,
            locations: locations,
            organizations: organizations,
            facilities: facilities,
            questionnaires: questionnaires,
            questionnaire_responses: questionnaire_responses,
            save_in_progress: save_in_progress
          )

          aggregated_data.combine
        end
      end

      ##
      # Gets a patient resource from the Health API.
      #
      # @return [FHIR::Patient::ClientReply] an instance of ClientReply
      #
      def get_patient
        @get_patient ||= patient_service.get(user.icn)
      end

      ##
      # Gets a list of Appointments from the Lighthouse Health API.
      #
      # @return [FHIR::Bundle] an object containing the
      # entries for FHIR::Appointment objects
      #
      def get_lighthouse_appointments
        @get_lighthouse_appointments ||=
          lighthouse_appointment_service.search(
            patient: user.icn,
            date: [date_ge_one_month_ago, date_le_two_weeks_from_now],
            _count: '100'
          )
      end

      ##
      # Gets a list of Locations from the `lighthouse_appointments` array
      # with a single request using the `_id` param
      #
      # @return [Array] a list of Locations
      #
      def get_locations
        location_references =
          lighthouse_appointments.each_with_object({}) do |appt, acc|
            reference = appt.resource.participant.first.actor.reference
            location_id = reference.match(ID_MATCHER)[1]

            acc[location_id] ||= []
            acc[location_id] << appt
          end

        clinic_identifiers = location_references&.keys&.join(',')
        location_response = location_service.search(_id: clinic_identifiers, _count: '100')

        location_response&.resource&.entry
      end

      ##
      # Returns an array of Organizations from the Health API for the `locations` array
      # with a single request using the `_id` param
      #
      # @return [Array] a list of Organizations
      #
      def get_organizations
        org_references =
          locations.each_with_object({}) do |loc, acc|
            reference = loc.resource.managingOrganization.reference
            org_id = reference.match(ID_MATCHER)[1]

            acc[org_id] ||= []
            acc[org_id] << loc
          end

        facility_identifiers = org_references&.keys&.join(',')
        org_response = organization_service.search(_id: facility_identifiers, _count: '100')

        org_response&.resource&.entry
      end

      ##
      # Return a list of facilities from the Facilities API
      # so that we can add phone numbers to our organizations
      #
      # @return [Array]
      #
      def get_facilities
        list = organizations.map { |org| org.resource.identifier.last.value }
        facilities_ids = list.join(',')

        facilities_request.get(facilities_ids)
      end

      ##
      # Gets a list of Questionnaires from the PGD.
      #
      # @return [FHIR::Bundle] an object containing the
      # entries for FHIR::Questionnaire objects
      #
      def get_questionnaires
        @get_questionnaires ||= questionnaire_service.search('context-type-value': get_use_context)
      end

      ##
      # Gets a list of QuestionnaireResponses that were created a year ago in the past,
      # AND a year into the future, for the user from the Lighthouse PGD
      #
      # @return [FHIR::Bundle]
      #
      def get_questionnaire_responses
        @get_questionnaire_responses ||=
          questionnaire_response_service.search(
            source: user.icn,
            authored: [date_ge_one_month_ago, date_le_two_weeks_from_now],
            _count: '100'
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
      # Builds the use context string, which will be used to query for Questionnaires,
      # from a list of Locations
      #
      # @return [String]
      #
      def get_use_context
        use_context_array =
          locations.each_with_object([]) do |loc, accumulator|
            key = "venue$#{loc.resource.identifier.last.value}"

            accumulator << key
          end

        use_context_array.join(USE_CONTEXT_DELIMITER)
      end

      private

      def date_ge_one_month_ago
        month = tz_date_string(1.month.ago)

        "ge#{month}"
      end

      def date_le_two_weeks_from_now
        weeks = tz_date_string(2.weeks.from_now)

        "le#{weeks}"
      end

      def tz_date_string(span)
        span.in_time_zone.to_date.to_s
      end

      def default_response
        { data: [] }
      end
    end
  end
end
