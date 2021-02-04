# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'health_quest appointments', type: :request, skip_mvi: true do
  include SchemaMatchers

  before do
    Flipper.enable('show_healthcare_experience_questionnaire')
    sign_in_as(current_user)
    allow_any_instance_of(HealthQuest::UserService).to receive(:session).and_return('stubbed_token')
    allow_any_instance_of(HealthQuest::AppointmentService).to receive(:get_appointment_by_id)
      .with(anything).and_return(appt_body)
  end

  describe 'GET appointments' do
    context 'health_quest user' do
      let(:current_user) { build(:user, :health_quest) }
      let(:appt_body) { HealthQuest::AppointmentService.new(current_user).mock_appointment }

      it 'has an instance of a va appointment serializer' do
        expect(HealthQuest::V0::VAAppointmentsSerializer).to receive(:new).once

        get '/health_quest/v0/appointments/132'
      end

      it 'is successful' do
        get '/health_quest/v0/appointments/132'

        expect(response).to have_http_status(:success)
      end

      it 'response body is a String' do
        get '/health_quest/v0/appointments/132'

        expect(response.body).to be_a(String)
      end

      it 'has attributes' do
        get '/health_quest/v0/appointments/132'

        appointment_attr = JSON.parse(response.body)['data']['attributes']

        expect(appointment_attr['start_date']).to eq('2020-08-26T15:00:00Z')
        expect(appointment_attr['sta6aid']).to eq('983')
        expect(appointment_attr['clinic_id']).to eq('848')
        expect(appointment_attr['clinic_friendly_name']).to eq('CHY PC VAR2')
        expect(appointment_attr['facility_id']).to eq('983')
        expect(appointment_attr['community_care']).to eq(false)
        expect(appointment_attr['patient_icn']).to eq('1013124304V115761')
        expect(appointment_attr['vds_appointments']).to be_a(Array)
      end
    end
  end
end
