# frozen_string_literal: true

module Eps
  class DraftAppointmentService
    def initialize(user)
      @user = user
      @appointments_service = VAOS::V2::AppointmentsService.new(user)
      @eps_provider_service = Eps::ProviderService.new(user)
      @eps_appointment_service = Eps::AppointmentService.new(user)
    end

    def call(referral_id, pagination_params)
      referral_data = fetch_referral_data(referral_id)

      referral_validation = check_referral_data_validation(referral_data)
      return referral_validation unless referral_validation[:success]

      referral_check = check_referral_usage(referral_id, pagination_params)
      return referral_check unless referral_check[:success]

      draft_appointment = create_draft_appointment(referral_id)

      provider = fetch_provider(referral_data[:provider_id])
      slots = fetch_provider_slots(referral_data)

      drive_time = fetch_drive_times(@user, provider)
      build_response(draft_appointment, provider, slots, drive_time)
    end

    private

    attr_reader :eps_provider_service, :appointments_service, :eps_appointment_service

    def fetch_referral_data(referral_id)
      eps_redis_client = Eps::RedisClient.new
      eps_redis_client.fetch_referral_attributes(referral_number: referral_id)
    end

    def check_referral_data_validation(referral_data)
      validation_result = validate_referral_data(referral_data)
      if validation_result[:valid]
        { success: true }
      else
        missing_attributes = validation_result[:missing_attributes]

        {
          success: false,
          json: {
            errors: [{
              title: 'Invalid referral data',
              detail: "Required referral data is missing or incomplete: #{missing_attributes}"
            }]
          },
          status: :unprocessable_entity
        }
      end
    end

    def validate_referral_data(referral_data)
      return { valid: false, missing_attributes: ['all required attributes'] } if referral_data.nil?

      required_attributes = %i[provider_id appointment_type_id start_date end_date]
      missing_attributes = required_attributes.select { |attr| referral_data[attr].blank? }

      {
        valid: missing_attributes.empty?,
        missing_attributes: missing_attributes.map(&:to_s).join(', ')
      }
    end

    def check_referral_usage(referral_id, pagination_params)
      check = appointments_service.referral_appointment_already_exists?(referral_id, pagination_params)

      if check[:error]
        { success: false, json: { message: "Error checking appointments: #{check[:failures]}" },
          status: :bad_gateway }
      elsif check[:exists]
        { success: false, json: { message: 'No new appointment created: referral is already used' },
          status: :unprocessable_entity }
      else
        { success: true }
      end
    end

    def create_draft_appointment(referral_id)
      eps_appointment_service.create_draft_appointment(referral_id: referral_id)
    end

    def fetch_provider(provider_id)
      eps_provider_service.get_provider_service(provider_id:)
    end

    def fetch_provider_slots(referral_data)
      eps_provider_service.get_provider_slots(
        referral_data[:provider_id],
        {
          appointmentTypeId: referral_data[:appointment_type_id],
          startOnOrAfter: referral_data[:start_date],
          startBefore: referral_data[:end_date]
        }
      )
    end

    def fetch_drive_times(user, provider)
      user_address = user.vet360_contact_info&.residential_address

      return nil unless user_address&.latitude && user_address.longitude

      eps_provider_service.get_drive_times(
        destinations: {
          provider.id => {
            latitude: provider.location[:latitude],
            longitude: provider.location[:longitude]
          }
        },
        origin: {
          latitude: user_address.latitude,
          longitude: user_address.longitude
        }
      )
    end

    def build_response(draft_appointment, provider, slots, drive_time)
      response_data = OpenStruct.new(id: draft_appointment.id, provider:, slots:, drive_time:)
      serialized = Eps::DraftAppointmentSerializer.new(response_data)
      { json: serialized, status: :created }
    end
  end
end
