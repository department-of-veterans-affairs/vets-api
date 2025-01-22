# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::QuestionnaireResponsesFormatter do
  subject { described_class }

  describe 'constants' do
    it 'has an ID_MATCHER' do
      expect(subject::ID_MATCHER).to eq(/([I2\-a-zA-Z0-9]+)\z/i)
    end
  end

  describe '.build' do
    it 'returns an instance of subject' do
      expect(subject.build([])).to be_a(HealthQuest::QuestionnaireManager::QuestionnaireResponsesFormatter)
    end
  end

  describe 'attributes' do
    it 'responds to qr_array' do
      expect(subject.build([]).respond_to?(:qr_array)).to be(true)
    end
  end

  describe '#appointment_id' do
    let(:ref) { '/my/Appointment/I2-SLRRT64GFGJAJGX62Q55N' }

    it 'gets an appointment_id from a reference field' do
      expect(subject.build([]).appointment_id(ref)).to eq('I2-SLRRT64GFGJAJGX62Q55N')
    end
  end

  describe '#to_h' do
    let(:ref) { double('Reference', reference: '/my/Appointment/I2-SLRRT64GFGJAJGX62Q55N') }
    let(:qr) { double('QuestionnaireResponse', resource: double('Resource', subject: ref)) }
    let(:qr_array) { [qr] }

    it 'builds a formatted hash' do
      expect(subject.build(qr_array).to_h).to eq({ 'I2-SLRRT64GFGJAJGX62Q55N' => [qr] })
    end
  end

  describe '#reference' do
    let(:ref) { double('Reference', reference: '/my/Appointment/I2-SLRRT64GFGJAJGX62Q55N') }
    let(:qr) { double('QuestionnaireResponse', resource: double('Resource', subject: ref)) }

    it 'returns a reference field' do
      expect(subject.build([]).reference(qr)).to eq('/my/Appointment/I2-SLRRT64GFGJAJGX62Q55N')
    end
  end
end
