# frozen_string_literal: true

require 'claims_api/poa_vbms_sidekiq'
require 'claims_api/v2/poa_pdf_constructor/organization'
require 'claims_api/v2/poa_pdf_constructor/individual'
require 'claims_api/stamp_signature_error'

module ClaimsApi
  module V2
    class PoaFormBuilderJob < ClaimsApi::ServiceBase
      include ClaimsApi::PoaVbmsSidekiq

      # Generate a 21-22 or 21-22a form for a given POA request.
      # Uploads the generated form to VBMS. If successfully uploaded,
      # it queues a job to update the POA code in BGS, as well.
      #
      # @param power_of_attorney_id [String] Unique identifier of the submitted POA
      def perform(power_of_attorney_id, form_number, user_profile)
        power_of_attorney = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)

        output_path = pdf_constructor(form_number).construct(data(power_of_attorney, form_number, user_profile),
                                                             id: power_of_attorney.id)
        upload_to_vbms(power_of_attorney, output_path)
        ClaimsApi::PoaUpdater.perform_async(power_of_attorney.id)
      rescue VBMS::Unknown
        rescue_vbms_error(power_of_attorney)
      rescue Errno::ENOENT
        rescue_file_not_found(power_of_attorney)
      end

      def pdf_constructor(form_number)
        if form_number == '2122A'
          ClaimsApi::V2::PoaPdfConstructor::Individual.new
        else
          ClaimsApi::V2::PoaPdfConstructor::Organization.new
        end
      end

      #
      # Combine form_data with auth_headers and signature data
      #
      # @param power_of_attorney [ClaimsApi::PowerOfAttorney] Record for this poa change request
      # @param form_number [String] Either 2122 or 2122A
      #
      # @return [Hash] All data to be inserted into pdf
      def data(power_of_attorney, form_number, user_profile)
        res = power_of_attorney
              .form_data.deep_merge({
                                      'veteran' => {
                                        'firstName' => power_of_attorney.auth_headers['va_eauth_firstName'],
                                        'lastName' => power_of_attorney.auth_headers['va_eauth_lastName'],
                                        'ssn' => power_of_attorney.auth_headers['va_eauth_pnid'],
                                        'birthdate' => power_of_attorney.auth_headers['va_eauth_birthdate']
                                      }
                                    })

        signatures = if form_number == '2122A'
                       individual_signatures(power_of_attorney, user_profile)
                     else
                       organization_signatures(power_of_attorney, user_profile)
                     end

        res.merge!({ 'text_signatures' => signatures })
        res
      end

      def organization_signatures(power_of_attorney, user_profile)
        rep_first_name = power_of_attorney.form_data['serviceOrganization']['firstName']
        rep_last_name = power_of_attorney.form_data['serviceOrganization']['lastName']
        first_name, last_name = veteran_or_claimant_signature(power_of_attorney, user_profile)
        {
          'page2' => [
            {
              'signature' => "#{first_name} " \
                             "#{last_name} - signed via api.va.gov",
              'x' => 35,
              'y' => 240
            },
            {
              'signature' => "#{rep_first_name} #{rep_last_name} - signed via api.va.gov",
              'x' => 35,
              'y' => 200
            }
          ]
        }
      end

      def individual_signatures(power_of_attorney, user_profile)
        first_name = power_of_attorney.form_data['representative']['firstName']
        last_name = power_of_attorney.form_data['representative']['lastName']
        {
          'page1' => individual_page1_signatures(power_of_attorney, first_name, last_name),
          'page2' => individual_page2_signatures(power_of_attorney, first_name, last_name, user_profile)
        }
      end

      def individual_page1_signatures(power_of_attorney, first_name, last_name)
        [
          {
            'signature' => "#{power_of_attorney.auth_headers['va_eauth_firstName']} " \
                           "#{power_of_attorney.auth_headers['va_eauth_lastName']} - signed via api.va.gov",
            'x' => 35,
            'y' => 73
          },
          {
            'signature' => "#{first_name} #{last_name} - signed via api.va.gov",
            'x' => 35,
            'y' => 100
          }
        ]
      end

      def individual_page2_signatures(power_of_attorney, rep_first_name, rep_last_name, user_profile)
        first_name, last_name = veteran_or_claimant_signature(power_of_attorney, user_profile)
        [
          {
            'signature' => "#{first_name} " \
                           "#{last_name} - signed via api.va.gov",
            'x' => 35,
            'y' => 306
          },
          {
            'signature' => "#{rep_first_name} #{rep_last_name} - signed via api.va.gov",
            'x' => 35,
            'y' => 200
          }
        ]
      end

      def veteran_or_claimant_signature(power_of_attorney, user_profile)
        if user_profile&.status == :ok
          first_name = user_profile.profile.given_names.first
          last_name = user_profile.profile.family_name
        else
          first_name = power_of_attorney.auth_headers['va_eauth_firstName']
          last_name = power_of_attorney.auth_headers['va_eauth_lastName']
        end
        [first_name, last_name]
      end

      def mpi_service
        @service ||= MPI::Service.new
      end
    end
  end
end
