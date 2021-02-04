# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::OptionsBuilder do
  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838') }
  let(:options_builder) { subject.manufacture(user, filters) }
  let(:qr_filter) { { resource_name: 'questionnaire_response' } }
  let(:q_filter) { { resource_name: 'questionnaire' } }
  let(:lighthouse) { Settings.hqva_mobile.lighthouse }

  describe '.manufacture' do
    let(:filters) { {}.with_indifferent_access }

    it 'returns an OptionsBuilder instance' do
      expect(subject.manufacture(nil, nil)).to be_an_instance_of(subject)
    end
  end

  describe 'object attributes' do
    let(:filters) { {}.with_indifferent_access }

    it 'responds to set attributes' do
      expect(options_builder.respond_to?(:user)).to eq(true)
      expect(options_builder.respond_to?(:filters)).to eq(true)
    end
  end

  describe '#appointment_id' do
    let(:filters) { qr_filter.merge!(appointment_id: '123').with_indifferent_access }

    it 'has an appointment_id' do
      expect(options_builder.appointment_id).to eq('123')
    end
  end

  describe '#resource_created_date' do
    let(:filters) { qr_filter.merge!(authored: '2021-12-26').with_indifferent_access }

    it 'has a resource_created_date' do
      expect(options_builder.resource_created_date).to eq('2021-12-26')
    end
  end

  describe '#context_type_value' do
    let(:filters) { q_filter.merge!(use_context: 'venue$534/12975,venue$534/12976').with_indifferent_access }

    it 'has a context_type_value' do
      expect(options_builder.context_type_value).to eq('venue$534/12975,venue$534/12976')
    end
  end

  describe '#appointment_reference' do
    let(:filters) { qr_filter.merge!(appointment_id: '123').with_indifferent_access }

    it 'has an appointment reference link' do
      expect(options_builder.appointment_reference)
        .to eq("#{lighthouse.url}#{lighthouse.pgd_path}/NamingSystem/va-appointment-identifier|123")
    end
  end

  describe '#registry' do
    context 'when resource is questionnaire_response' do
      let(:filters) { qr_filter.merge!(appointment_id: '123').with_indifferent_access }

      it 'has relevant keys' do
        expect(options_builder.registry[filters.delete(:resource_name).to_sym].keys)
          .to eq(%i[appointment_id patient authored])
      end
    end

    context 'when resource is questionnaire' do
      let(:filters) { q_filter.merge!(use_context: '123').with_indifferent_access }

      it 'has relevant keys' do
        expect(options_builder.registry[filters.delete(:resource_name).to_sym].keys).to eq(%i[use_context])
      end
    end
  end

  describe '#to_hash' do
    context 'when resource is questionnaire_response' do
      context 'when appointment_id' do
        let(:filters) { qr_filter.merge!(appointment_id: '123').with_indifferent_access }

        it 'returns a _tag hash' do
          expect(options_builder.to_hash)
            .to eq({ _tag: 'https://sandbox-api.va.gov/services/pgd/v0/r4/NamingSystem/va-appointment-identifier|123' })
        end
      end

      context 'when patient' do
        let(:filters) { qr_filter.merge!(patient: '1008596379V859838').with_indifferent_access }

        it 'returns a subject hash' do
          expect(options_builder.to_hash)
            .to eq({ subject: '1008596379V859838' })
        end
      end

      context 'when authored' do
        let(:filters) { qr_filter.merge!(authored: '2021-12-26').with_indifferent_access }

        it 'returns an authored hash' do
          expect(options_builder.to_hash)
            .to eq({ authored: '2021-12-26' })
        end
      end
    end

    context 'when resource is questionnaire' do
      context 'when use_context' do
        let(:filters) { q_filter.merge!(use_context: '').with_indifferent_access }

        it 'returns an use_context hash' do
          expect(options_builder.to_hash)
            .to eq({ 'context-type-value': '' })
        end
      end
    end
  end
end
