# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::OptionsBuilder do
  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838') }
  let(:filters) { {}.with_indifferent_access }
  let(:options_builder) { subject.manufacture(user, filters) }

  describe '.manufacture' do
    it 'returns an OptionsBuilder instance' do
      expect(subject.manufacture(nil, nil)).to be_an_instance_of(subject)
    end
  end

  describe 'object attributes' do
    it 'responds to set attributes' do
      expect(options_builder.respond_to?(:user)).to eq(true)
      expect(options_builder.respond_to?(:filters)).to eq(true)
    end
  end

  describe '#appointment_id' do
    let(:filters) { { appointment_id: '123' }.with_indifferent_access }

    it 'has an appointment_id' do
      expect(options_builder.appointment_id).to eq('123')
    end
  end

  describe '#subject_reference' do
    let(:filters) { { appointment_id: '123' }.with_indifferent_access }

    it 'has an appointment reference link' do
      expect(options_builder.subject_reference)
        .to eq("#{Settings.hqva_mobile.url}/appointments/v1/patients/1008596379V859838/Appointment/123")
    end
  end

  describe '#to_hash' do
    context 'without filters' do
      it 'has a user option' do
        expect(options_builder.to_hash).to eq({ author: '1008596379V859838' })
      end
    end

    context 'with appointment_id filter' do
      let(:filters) { { appointment_id: '123' }.with_indifferent_access }

      it 'has a subject option' do
        expect(options_builder.to_hash)
          .to eq({ subject: "#{Settings.hqva_mobile.url}/appointments/v1/patients/1008596379V859838/Appointment/123" })
      end
    end
  end
end
