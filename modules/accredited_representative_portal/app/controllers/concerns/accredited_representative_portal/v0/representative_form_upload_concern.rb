# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    module RepresentativeFormUploadConcern
      extend ActiveSupport::Concern

      private

      def attachment_guids
        guids = []
        guids << submit_params[:confirmationCode] if submit_params[:confirmationCode].present?

        if submit_params[:supportingDocuments].is_a?(Array)
          guids += submit_params[:supportingDocuments].pluck(:confirmationCode).compact
        end

        guids
      end

      def claimant_representative
        defined?(@claimant_representative) and
          return @claimant_representative

        @claimant_representative =
          claimant_icn.presence &&
          ClaimantRepresentative.find(
            claimant_icn:, power_of_attorney_holder_memberships:
              current_user.power_of_attorney_holder_memberships
          )
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

      def submit_params
        @submit_params ||=
          params.require(:representative_form_upload).permit(
            [
              :formName, :confirmationCode,
              { supportingDocuments: %i[name confirmationCode size isEncrypted] },
              { formData: [
                :veteranSsn, :postalCode, :veteranDateOfBirth, :formNumber,
                :email, :claimantDateOfBirth, :claimantSsn, :vaFileNumber,
                { claimantFullName: %i[first last] },
                { veteranFullName: %i[first last] }
              ] }
            ]
          )
      end
    end
  end
end
