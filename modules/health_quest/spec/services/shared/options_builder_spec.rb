# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Shared::OptionsBuilder do
  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838') }
  let(:options_builder) { subject.manufacture(user, filters) }
  let(:qr_filter) { { resource_name: 'questionnaire_response' } }
  let(:appt_filter) { { resource_name: 'appointment' } }
  let(:q_filter) { { resource_name: 'questionnaire' } }
  let(:loc_filter) { { resource_name: 'location' } }
  let(:org_filter) { { resource_name: 'organization' } }
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
      expect(options_builder.respond_to?(:user)).to be(true)
      expect(options_builder.respond_to?(:filters)).to be(true)
    end
  end

  describe '#appointment_id' do
    let(:filters) { qr_filter.merge!(subject: '123').with_indifferent_access }

    it 'has an appointment_id' do
      expect(options_builder.appointment_id).to eq('123')
    end
  end

  describe '#clinic_id' do
    let(:filters) { appt_filter.merge!(location: 'abcd').with_indifferent_access }

    it 'has a clinic_id' do
      expect(options_builder.clinic_id).to eq('abcd')
    end
  end

  describe '#appointment_dates' do
    let(:filters) { appt_filter.merge!(date: '2021-12-26').with_indifferent_access }

    it 'has an appointment_dates' do
      expect(options_builder.appointment_dates).to eq('2021-12-26')
    end
  end

  describe '#resource_created_date' do
    let(:filters) { qr_filter.merge!(authored: '2021-12-26').with_indifferent_access }

    it 'has a resource_created_date' do
      expect(options_builder.resource_created_date).to eq('2021-12-26')
    end
  end

  describe '#context_type_value' do
    let(:filters) { q_filter.merge!('context-type-value': 'venue$534/12975,venue$534/12976').with_indifferent_access }

    it 'has a context_type_value' do
      expect(options_builder.context_type_value).to eq('venue$534/12975,venue$534/12976')
    end
  end

  describe '#location_ids' do
    let(:filters) { loc_filter.merge!(_id: '123abc,456def').with_indifferent_access }

    it 'has a location_ids' do
      expect(options_builder.location_ids).to eq('123abc,456def')
    end
  end

  describe '#org_id' do
    let(:filters) { loc_filter.merge!(organization: '456def').with_indifferent_access }

    it 'has an org_id' do
      expect(options_builder.org_id).to eq('456def')
    end
  end

  describe '#organization_ids' do
    let(:filters) { org_filter.merge!(_id: '123abc,456def').with_indifferent_access }

    it 'has a organization_ids' do
      expect(options_builder.organization_ids).to eq('123abc,456def')
    end
  end

  describe '#organization_identifier' do
    let(:filters) { org_filter.merge!(identifier: '123abc').with_indifferent_access }

    it 'has an organization_identifier' do
      expect(options_builder.organization_identifier).to eq('123abc')
    end
  end

  describe '#location_identifier' do
    let(:filters) { loc_filter.merge!(identifier: 'vha_123abc').with_indifferent_access }

    it 'has an location_identifier' do
      expect(options_builder.location_identifier).to eq('vha_123abc')
    end
  end

  describe '#resource_count' do
    let(:filters) { org_filter.merge!(_count: '30').with_indifferent_access }

    it 'has a resource_count' do
      expect(options_builder.resource_count).to eq('30')
    end
  end

  describe '#resource_page' do
    let(:filters) { org_filter.merge!(page: '3').with_indifferent_access }

    it 'has a resource_count' do
      expect(options_builder.resource_page).to eq('3')
    end
  end

  describe '#appointment_reference' do
    let(:filters) { qr_filter.merge!(subject: '123').with_indifferent_access }

    it 'has an appointment reference link' do
      expect(options_builder.appointment_reference)
        .to eq("#{lighthouse.url}#{lighthouse.pgd_path}/NamingSystem/va-appointment-identifier|123")
    end
  end

  describe '#registry' do
    context 'when resource is appointment' do
      let(:filters) { appt_filter.merge!(patient: '123').with_indifferent_access }

      it 'has relevant keys' do
        expect(options_builder.registry[filters.delete(:resource_name).to_sym].keys)
          .to eq(%i[patient date location _count page])
      end
    end

    context 'when resource is questionnaire_response' do
      let(:filters) { qr_filter.merge!(subject: '123').with_indifferent_access }

      it 'has relevant keys' do
        expect(options_builder.registry[filters.delete(:resource_name).to_sym].keys)
          .to eq(%i[subject source authored _count page])
      end
    end

    context 'when resource is questionnaire' do
      let(:filters) { q_filter.merge!('context-type-value': '123').with_indifferent_access }

      it 'has relevant keys' do
        expect(options_builder.registry[filters.delete(:resource_name).to_sym].keys)
          .to eq(%i[context-type-value _count page])
      end
    end

    context 'when resource is location' do
      let(:filters) { loc_filter.merge!(_id: '123abc,456def').with_indifferent_access }

      it 'has relevant keys' do
        expect(options_builder.registry[filters.delete(:resource_name).to_sym].keys)
          .to eq(%i[_id organization identifier _count page])
      end
    end

    context 'when resource is organization' do
      let(:filters) { org_filter.merge!(_id: '123abc,456def').with_indifferent_access }

      it 'has relevant keys' do
        expect(options_builder.registry[filters.delete(:resource_name).to_sym].keys)
          .to eq(%i[_id identifier _count page])
      end
    end
  end

  describe '#to_hash' do
    context 'when resource is questionnaire_response' do
      context 'when appointment_id' do
        let(:filters) { qr_filter.merge!(subject: '123').with_indifferent_access }

        it 'returns a subject hash' do
          reference_url =
            'https://sandbox-api.va.gov/services/pgd/v0/r4/NamingSystem/va-appointment-identifier|123'

          expect(options_builder.to_hash).to eq({ subject: reference_url })
        end
      end

      context 'when patient' do
        let(:filters) { qr_filter.merge!(source: '1008596379V859838').with_indifferent_access }

        it 'returns a subject hash' do
          expect(options_builder.to_hash)
            .to eq({ source: '1008596379V859838' })
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
        let(:filters) { q_filter.merge!('context-type-value': '').with_indifferent_access }

        it 'returns an use_context hash' do
          expect(options_builder.to_hash)
            .to eq({ 'context-type-value': '' })
        end
      end
    end

    context 'when resource is location' do
      context 'when _id' do
        let(:filters) { loc_filter.merge!(_id: '123abc,456def').with_indifferent_access }

        it 'returns an _id hash' do
          expect(options_builder.to_hash)
            .to eq({ _id: '123abc,456def' })
        end
      end
    end

    context 'when resource is organization' do
      context 'when _id' do
        let(:filters) { org_filter.merge!(_id: '123abc,456def').with_indifferent_access }

        it 'returns an _id hash' do
          expect(options_builder.to_hash)
            .to eq({ _id: '123abc,456def' })
        end
      end
    end
  end
end
