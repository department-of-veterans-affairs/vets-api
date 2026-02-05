# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'NextStepsEmailController', type: :request do
  describe 'POST #create' do
    let(:base_path) { '/representation_management/v0/next_steps_email' }
    let(:accredited_individual) do
      create(:accredited_individual, individual_type: 'attorney', first_name: 'Bob', last_name: 'Law',
                                     address_line1: '123 Fake St', address_line2: 'Bldg 2', address_line3: 'Suite 3',
                                     city: 'Portland', state_code: 'OR', zip_code: '97214', country_code_iso3: 'USA')
    end
    let(:params) do
      {
        next_steps_email: {
          email_address: 'email@example.com',
          first_name: 'First',
          form_name: 'Form Name',
          form_number: 'Form Number',
          entity_type: 'individual',
          entity_id: accredited_individual.id
        }
      }
    end

    context 'When submitting all fields with valid data' do
      it 'responds with a ok status' do
        post(base_path, params:)
        expect(response).to have_http_status(:ok)
      end

      it 'responds with the expected body' do
        post(base_path, params:)
        expect(response.body).to eq({ message: 'Email enqueued' }.to_json)
      end

      it 'enqueues the email' do
        expect(VANotify::EmailJob).to receive(:perform_async).with(
          params[:next_steps_email][:email_address],
          'appoint_a_representative_confirmation_email_template_id', # This is the actual value from the settings file
          {
            # The first_name is the only key here that has an underscore.
            # That is intentional.  All the keys here match the keys in the
            # template.
            'first_name' => 'First',
            'form name' => 'Form Name',
            'form number' => 'Form Number',
            'representative type' => 'attorney',
            'representative name' => 'Bob Law',
            'representative address' => '123 Fake St Bldg 2 Suite 3 Portland, OR 97214 USA'
          },
          'fake_secret',
          { callback_klass: 'AccreditedRepresentativePortal::EmailDeliveryStatusCallback',
            callback_metadata: {
              form_number: 'Form Number',
              statsd_tags: {
                service: 'representation-management',
                function: 'appoint_a_representative_confirmation_email'
              }
            } }
        )
        post(base_path, params:)
      end

      it 'does not pass callback options when' \
         'accredited_representative_portal_email_delivery_callback feature flag is disabled' do
        allow(Flipper).to receive(:enabled?)
          .with(:accredited_representative_portal_email_delivery_callback)
          .and_return(false)

        expect(VANotify::EmailJob).to receive(:perform_async).with(
          params[:next_steps_email][:email_address],
          'appoint_a_representative_confirmation_email_template_id',
          {
            'first_name' => 'First',
            'form name' => 'Form Name',
            'form number' => 'Form Number',
            'representative type' => 'attorney',
            'representative name' => 'Bob Law',
            'representative address' => '123 Fake St Bldg 2 Suite 3 Portland, OR 97214 USA'
          },
          'fake_secret',
          nil
        )

        post(base_path, params:)
      end
    end

    context 'when triggering validation errors' do
      context 'when submitting without the single required attribute for a single validation error' do
        before do
          params[:next_steps_email][:email_address] = nil
          post(base_path, params:)
        end

        it 'responds with an unprocessable entity status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          expect(response.body).to eq({ errors: ["Email address can't be blank"] }.to_json)
        end
      end

      context 'when submitting without multiple required attributes' do
        before do
          params[:next_steps_email][:email_address] = nil
          params[:next_steps_email][:first_name] = nil
          post(base_path, params:)
        end

        it 'responds with an unprocessable entity status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          expect(response.body).to include("Email address can't be blank")
          expect(response.body).to include("First name can't be blank")
        end
      end
    end

    context "when the feature flag 'appoint_a_representative_enable_pdf' is disabled" do
      before do
        Flipper.disable(:appoint_a_representative_enable_pdf) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      end

      after do
        Flipper.enable(:appoint_a_representative_enable_pdf) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      end

      it 'returns a 404' do
        post(base_path, params:)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
