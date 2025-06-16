# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    module RepresentativeFormUploadConcern # rubocop:disable Metrics/ModuleLength
      extend ActiveSupport::Concern

      private

      ##
      # TODO: Client will need to send us multiple attachment guids for multi-
      # form upload.
      #
      def attachment_guids
        [submit_params[:confirmationCode]]
      end

      def claimant_representative
        defined?(@claimant_representative) and
          return @claimant_representative

        @claimant_representative =
          if claimant_icn.present?
            ClaimantRepresentative.find do |finder|
              finder.for_claimant(
                icn: claimant_icn
              )

              finder.for_representative(
                icn: current_user.icn,
                email: current_user.email,
                all_emails: current_user.all_emails
              )
            end
          end
      end

      def claimant_icn
        defined?(@claimant_icn) and
          return @claimant_icn

        @claimant_icn =
          begin
            claimant =
              metadata[:dependent] ||
              metadata[:veteran]

            mpi_response =
              MPI::Service.new.find_profile_by_attributes(
                ssn: claimant[:ssn],
                first_name: claimant[:name][:first],
                last_name: claimant[:name][:last],
                birth_date: claimant[:dateOfBirth]
              )

            mpi_response.profile&.icn
          end
      end

      def metadata # rubocop:disable Metrics/MethodLength
        @metadata ||=
          {}.tap do |memo|
            form_data = submit_params[:formData]

            memo[:veteran] = {
              ssn: form_data[:veteranSsn],
              dateOfBirth: form_data[:veteranDateOfBirth],
              postalCode: form_data[:postalCode],
              name: {
                first: form_data[:veteranFullName][:first],
                last: form_data[:veteranFullName][:last]
              }
            }

            memo[:dependent] =
              ##
              # Note that "claimant" is not as correct a name as "dependent" here.
              # The claimant is either a dependent or the Veteran.
              #
              if form_data[:claimantSsn].present?
                {
                  ssn: form_data[:claimantSsn],
                  dateOfBirth: form_data[:claimantDateOfBirth],
                  name: {
                    first: form_data[:claimantFullName][:first],
                    last: form_data[:claimantFullName][:last]
                  }
                }
              end
          end
      end

      def submit_params # rubocop:disable Metrics/MethodLength
        @submit_params ||= begin
          unwrapped_params =
            params.require(:representative_form_upload)

          param_filters = [
            :formName,
            :confirmationCode,
            { formData: [
              :veteranSsn,
              :postalCode,
              :veteranDateOfBirth,
              :formNumber,
              :email,
              :claimantDateOfBirth,
              :claimantSsn,
              { claimantFullName: %i[first last] },
              { veteranFullName: %i[first last] }
            ] }
          ]

          ##
          # TODO: Remove. This is a workaround while we're in the situation that
          # OliveBranch modifies our params on staging but not on localhost.
          # We'll have fixed that bug when it leaves our params alone in both
          # environments.
          #
          # This `blank?` check approach should suffice to target this situation
          # without causing some other breakage.
          #
          if unwrapped_params[:formData].blank?
            ##
            # Manual snakification of `param_filters`. Not done programmatically
            # because the algorithm would be too long for throwaway code.
            #
            param_filters = [
              :confirmation_code,
              :form_name,
              { form_data: [
                :veteran_ssn,
                :postal_code,
                :veteran_date_of_birth,
                :form_number,
                :email,
                :claimant_date_of_birth,
                :claimant_ssn,
                { claimant_full_name: %i[first last] },
                { veteran_full_name: %i[first last] }
              ] }
            ]
          end

          ##
          # TODO: Remove. This is a part of the same workaround above. Once we
          # have a fix, this transformation will be purely redundant.
          #
          unwrapped_params
            .permit(*param_filters)
            .deep_transform_keys do |k|
              k.camelize(:lower)
            end
        end
      end
    end
  end
end
