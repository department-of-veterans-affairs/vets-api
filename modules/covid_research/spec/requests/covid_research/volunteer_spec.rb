# frozen_string_literal: true

require 'rails_helper'
require CovidResearch::Engine.root.join('spec', 'rails_helper.rb')

RSpec.describe 'CovidResearch::Volunteer', type: :request do
  describe 'POST /covid-research/volunteer/create' do
    let(:valid)   { read_fixture('valid-intake-submission.json') }
    let(:invalid) { read_fixture('no-name-submission.json') }
    let(:email_template) { 'signup_confirmation.html.erb' }

    before do
      Flipper.enable(:covid_volunteer_intake_backend_enabled)
    end

    it 'validates the payload' do
      expect_any_instance_of(CovidResearch::Volunteer::FormService).to receive(:valid?)

      post '/covid-research/volunteer/create', params: valid
    end

    context 'metrics' do
      it 'records a metric for each call' do
        expect { post '/covid-research/volunteer/create', params: valid }.to trigger_statsd_increment(
          'api.covid_research.volunteer.create.total', times: 1, value: 1
        )
      end

      it 'records a metric on failure' do
        expect { post '/covid-research/volunteer/create', params: invalid }.to trigger_statsd_increment(
          'api.covid_research.volunteer.create.fail', times: 1, value: 1
        )
      end
    end

    context 'with a valid payload' do
      it 'returns a 202' do
        post '/covid-research/volunteer/create', params: valid

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'with an invalid payload' do
      it 'returns a description of the errors' do
        post '/covid-research/volunteer/create', params: invalid

        expect(JSON.parse(response.body)).to have_key('errors')
      end

      it 'returns a 422 status' do
        post '/covid-research/volunteer/create', params: invalid

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'delivery feature flag' do
      let(:form_service) { CovidResearch::Volunteer::FormService }

      it 'schedules delivery when the `covid_volunteer_delivery` flag is true' do
        Flipper.enable(:covid_volunteer_delivery)
        allow_any_instance_of(form_service).to receive(:valid?).and_return(true)
        expect_any_instance_of(form_service).to receive(:queue_delivery)

        post '/covid-research/volunteer/create', params: valid
      end

      it 'does not schedule delivery when the `covid_volunteer_delivery` flag is false' do
        Flipper.disable(:covid_volunteer_delivery)
        allow_any_instance_of(form_service).to receive(:valid?).and_return(true)
        expect_any_instance_of(form_service).not_to receive(:queue_delivery)

        post '/covid-research/volunteer/create', params: valid
      end
    end

    context 'email confirmation' do
      let(:confirmation_job) { CovidResearch::Volunteer::ConfirmationMailerJob }

      it 'schedules delivery via Sidekiq' do
        expect(confirmation_job).to receive(:perform_async).with(JSON.parse(valid)['email'], email_template)

        post '/covid-research/volunteer/create', params: valid
      end
    end

    context 'with feature toggle off' do
      it 'returns a 404 status' do
        Flipper.disable(:covid_volunteer_intake_backend_enabled)
        post '/covid-research/volunteer/create', params: valid

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /covid-research/volunteer/update' do
    let(:valid)   { read_fixture('valid-update-submission.json') }
    let(:invalid) { read_fixture('no-name-submission.json') }
    let(:email_template) { 'update_confirmation.html.erb' }

    before do
      Flipper.enable(:covid_volunteer_update_enabled)
    end

    it 'validates the payload' do
      expect_any_instance_of(CovidResearch::Volunteer::FormService).to receive(:valid?)

      post '/covid-research/volunteer/update', params: valid
    end

    context 'metrics' do
      it 'records a metric for each call' do
        expect { post '/covid-research/volunteer/update', params: valid }.to trigger_statsd_increment(
          'api.covid_research.volunteer.update.total', times: 1, value: 1
        )
      end

      it 'records a metric on failure' do
        expect { post '/covid-research/volunteer/update', params: invalid }.to trigger_statsd_increment(
          'api.covid_research.volunteer.update.fail', times: 1, value: 1
        )
      end
    end

    context 'with a valid payload' do
      it 'returns a 202' do
        post '/covid-research/volunteer/update', params: valid

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'with an invalid payload' do
      it 'returns a description of the errors' do
        post '/covid-research/volunteer/update', params: invalid

        expect(JSON.parse(response.body)).to have_key('errors')
      end

      it 'returns a 422 status' do
        post '/covid-research/volunteer/update', params: invalid

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'feature flag' do
      let(:form_service) { CovidResearch::Volunteer::FormService }

      it 'schedules delivery when the `covid_volunteer_delivery` flag is true' do
        Flipper.enable(:covid_volunteer_delivery)
        allow_any_instance_of(form_service).to receive(:valid?).and_return(true)
        expect_any_instance_of(form_service).to receive(:queue_delivery)

        post '/covid-research/volunteer/update', params: valid
      end

      it 'does not schedule delivery when the `covid_volunteer_delivery` flag is false' do
        Flipper.disable(:covid_volunteer_delivery)
        allow_any_instance_of(form_service).to receive(:valid?).and_return(true)
        expect_any_instance_of(form_service).not_to receive(:queue_delivery)

        post '/covid-research/volunteer/update', params: valid
      end
    end

    # context 'email confirmation' do
    #   let(:confirmation_job) { CovidResearch::Volunteer::ConfirmationMailerJob }

    #   it 'schedules delivery via Sidekiq' do
    #     expect(confirmation_job).to receive(:perform_async).with(JSON.parse(valid)['email'], email_template)

    #     post '/covid-research/volunteer/update', params: valid
    #   end
    # end

    context 'with feature toggle off' do
      it 'returns a 404 status' do
        Flipper.disable(:covid_volunteer_update_enabled)
        post '/covid-research/volunteer/update', params: valid

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
