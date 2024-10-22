# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGenerator2122Controller < RepresentationManagement::V0::PdfGeneratorBaseController
      def create
        # TODO: Remove all this!
        if AccreditedIndividual.count.zero?
          FactoryBot.create(:accredited_individual,
                            first_name: 'John',
                            middle_initial: 'M',
                            last_name: 'Representative',
                            address_line1: '123 Fake Representative St',
                            city: 'Portland',
                            state_code: 'OR',
                            zip_code: '12345',
                            phone: '5555555555',
                            email: 'representative@example.com')
        end
        FactoryBot.create(:accredited_organization, name: 'Best VSO') if AccreditedOrganization.count.zero?
        p 'RepresentationManagement::V0::PdfGenerator2122Controller#create ' * 10, AccreditedIndividual.first.inspect,
          AccreditedOrganization.first.inspect
        form = RepresentationManagement::Form2122Data.new(flatten_form_params)

        if form.valid?
          Tempfile.create do |tempfile|
            tempfile.binmode
            RepresentationManagement::V0::PdfConstructor::Form2122.new(tempfile).construct(form)
            send_data tempfile.read,
                      filename: '21-22.pdf',
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
        params.require(:pdf_generator2122).permit(params_permitted)
      end

      def flatten_form_params
        {
          representative_id: form_params[:representative][:id],
          organization_id: form_params[:representative][:organization_id],
          record_consent: form_params[:record_consent],
          consent_limits: form_params[:consent_limits],
          consent_address_change: form_params[:consent_address_change]
        }.merge(flatten_veteran_params(form_params))
          .merge(flatten_claimant_params(form_params))
      end

      def flatten_veteran_params(veteran_params)
        super.merge(veteran_insurance_numbers: veteran_params.dig(:veteran, :insurance_numbers))
      end
    end
  end
end
