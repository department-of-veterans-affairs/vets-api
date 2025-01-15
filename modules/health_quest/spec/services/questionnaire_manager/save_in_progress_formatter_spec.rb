# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::SaveInProgressFormatter do
  subject { described_class }

  describe 'constants' do
    it 'has an ID_MATCHER' do
      expect(subject::ID_MATCHER).to eq(/HC-QSTNR_([I2\-a-zA-Z0-9]+)_/i)
    end
  end

  describe '.build' do
    it 'returns an instance of subject' do
      expect(subject.build([])).to be_a(HealthQuest::QuestionnaireManager::SaveInProgressFormatter)
    end
  end

  describe 'attributes' do
    it 'responds to sip_array' do
      expect(subject.build([]).respond_to?(:sip_array)).to be(true)
    end
  end

  describe '#appointment_id' do
    let(:sip) { double('InProgressForm', form_id: 'HC-QSTNR_I2-SLRRT64GFGJAJGX62Q55N_abc-123-def-455') }

    it 'gets an appointment_id from an object' do
      expect(subject.build([]).appointment_id(sip)).to eq('I2-SLRRT64GFGJAJGX62Q55N')
    end
  end

  describe '#to_h' do
    let(:sip) { double('InProgressForm', form_id: 'HC-QSTNR_I2-SLRRT64GFGJAJGX62Q55N_abc-123-def-455') }
    let(:sip_array) { [sip] }

    it 'builds a formatted hash' do
      expect(subject.build(sip_array).to_h).to eq({ 'I2-SLRRT64GFGJAJGX62Q55N' => [sip] })
    end
  end
end
