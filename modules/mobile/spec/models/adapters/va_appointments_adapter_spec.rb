# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::VAAppointments do
  let(:appointments) do
    file = File.read(Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'va_appointments.json'))
    JSON.parse(file)
  end

  it 'is true' do
    expect(subject.parse(appointments).length).to eq(10)
  end
end
