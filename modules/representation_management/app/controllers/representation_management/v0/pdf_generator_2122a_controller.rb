# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGenerator2122aController < RepresentationManagement::V0::PowerOfAttorneyRequestBaseController
      skip_before_action :authenticate
      before_action :load_user

      def create
        form = RepresentationManagement::Form2122aData.new(flatten_form_params)

        if form.valid?
          Tempfile.create do |tempfile|
            tempfile.binmode
            RepresentationManagement::V0::PdfConstructor::Form2122a.new(tempfile).construct(form)
            clear_saved_form('21-22') if form_params[:representative_submission_method] != 'digital'
            send_data tempfile.read,
                      filename: '21-22a.pdf',
                      type: 'application/pdf',
                      disposition: 'attachment',
                      status: :ok
          end
          # The Tempfile is automatically deleted after the block ends
        else
          render json: { errors: form.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def form_params
        params.require(:pdf_generator2122a).permit(
          params_permitted << { representative: representative_params_permitted }
        )
      end

      def flatten_form_params
        {
          representative_id: form_params[:representative][:id],
          record_consent: form_params[:record_consent],
          consent_limits: form_params[:consent_limits],
          consent_address_change: form_params[:consent_address_change],
          consent_inside_access: form_params[:consent_inside_access],
          consent_outside_access: form_params[:consent_outside_access],
          consent_team_members: form_params[:consent_team_members]
        }.merge(flatten_veteran_params(form_params))
          .merge(flatten_claimant_params(form_params))
      end

      def flatten_veteran_params(veteran_params)
        super.merge(veteran_service_number: veteran_params.dig(:veteran, :service_number),
                    veteran_service_branch: veteran_params.dig(:veteran, :service_branch))
      end
    end
  end
end
