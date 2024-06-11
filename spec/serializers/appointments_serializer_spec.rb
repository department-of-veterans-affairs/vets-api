# frozen_string_literal: true

require 'rails_helper'
require 'ihub/appointments/response'

describe AppointmentSerializer, type: :serializer do

  let(:appointment) { build_stubbed(:ihub_models_appointment) }
  let(:appointments_response) { IHub::Appointments::Response.new({appointments: [appointment]}) }

  subject { serialize(appointments_response, serializer_class: described_class) }

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :appointments as an array' do
    expect(attributes['appointments'].size).to eq appointments_response.appointments.size
  end

  it 'includes appointment with attributes' do
    expect(attributes['appointments'].first.keys).to eq appointment.attributes.keys.map(&:to_s)
  end

end
