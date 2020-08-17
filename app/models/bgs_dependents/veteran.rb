# frozen_string_literal: true

module BGSDependents
  class Veteran < Base
    attribute :participant_id, String
    attribute :ssn, String
    attribute :first_name, String
    attribute :middle_name, String
    attribute :last_name, String

    def initialize(proc_id, user)
      @proc_id = proc_id
      @user = user
      self.attributes = user_veteran_attributes
    end

    def formatted_params(payload)
      dependents_application = payload['dependents_application']

      vet_info = [
        *payload['veteran_information'],
        ['first', first_name],
        ['middle', middle_name],
        ['last', last_name],
        *dependents_application.dig('veteran_contact_information'),
        *dependents_application.dig('veteran_contact_information', 'veteran_address'),
        %w[vet_ind Y]
      ]

      if dependents_application['current_marriage_information']
        vet_info << ['martl_status_type_cd', marital_status(dependents_application)]
      end

      vet_info.to_h
    end

    def veteran_response(participant, va_file_number, address, end_product)
      {
        vnp_participant_id: participant[:vnp_ptcpnt_id],
        first_name: first_name,
        last_name: last_name,
        vnp_participant_address_id: address[:vnp_ptcpnt_addrs_id],
        file_number: va_file_number,
        address_line_one: address[:addrs_one_txt],
        address_line_two: address[:addrs_two_txt],
        address_line_three: address[:addrs_three_txt],
        address_country: address[:cntry_nm],
        address_state_code: address[:postal_cd],
        address_city: address[:city_nm],
        address_zip_code: address[:zip_prefix_nbr],
        type: 'veteran',
        benefit_claim_type_end_product: end_product
      }
    end

    private

    def user_veteran_attributes
      {
        participant_id: @user.participant_id,
        ssn: @user.ssn,
        first_name: @user.first_name,
        middle_name: @user.middle_name,
        last_name: @user.last_name
      }
    end

    def marital_status(dependents_application)
      spouse_lives_with_vet = dependents_application.dig('does_live_with_spouse', 'spouse_does_live_with_veteran')

      return nil if spouse_lives_with_vet.nil?

      spouse_lives_with_vet ? 'Married' : 'Separated'
    end
  end
end
