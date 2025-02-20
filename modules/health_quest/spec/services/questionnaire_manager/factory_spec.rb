# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::Factory do
  include HealthQuest::QuestionnaireManager::FactoryTypes

  subject { described_class }

  let(:user) { create(:user) }
  let(:session_store) { double('SessionStore', token: '123abc') }
  let(:session_service) do
    double('HealthQuest::Lighthouse::Session', user:, api: 'pgd_api', retrieve: session_store)
  end
  let(:client_reply) { double('FHIR::ClientReply') }
  let(:default_appointments) { double('FHIR::ClientReply', resource: double('Entry', entry: [])) }
  let(:default_location) { [double('FHIR::Location')] }
  let(:default_organization) { [double('FHIR::Organization')] }
  let(:default_facilities) { [double('Facilities')] }
  let(:appointments) { { data: [{}, {}] } }

  before do
    allow(HealthQuest::Lighthouse::Session).to receive(:build).and_return(session_service)
  end

  describe 'included modules' do
    it 'includes FactoryTypes' do
      expect(subject.ancestors).to include(HealthQuest::QuestionnaireManager::FactoryTypes)
    end
  end

  describe 'constants' do
    it 'has a HEALTH_CARE_FORM_PREFIX' do
      expect(subject::HEALTH_CARE_FORM_PREFIX).to eq('HC-QSTNR')
    end

    it 'has an USE_CONTEXT_DELIMITER' do
      expect(subject::USE_CONTEXT_DELIMITER).to eq(',')
    end

    it 'has an ID_MATCHER' do
      expect(subject::ID_MATCHER).to eq(/([I2\-a-zA-Z0-9]+)\z/i)
    end
  end

  describe 'object initialization' do
    let(:factory) { described_class.manufacture(user) }

    it 'responds to attributes' do
      expect(factory.respond_to?(:lighthouse_appointments)).to be(true)
      expect(factory.respond_to?(:locations)).to be(true)
      expect(factory.respond_to?(:organizations)).to be(true)
      expect(factory.respond_to?(:facilities)).to be(true)
      expect(factory.respond_to?(:aggregated_data)).to be(true)
      expect(factory.respond_to?(:patient)).to be(true)
      expect(factory.respond_to?(:questionnaires)).to be(true)
      expect(factory.respond_to?(:questionnaire_response)).to be(true)
      expect(factory.respond_to?(:save_in_progress)).to be(true)
      expect(factory.respond_to?(:lighthouse_appointment_service)).to be(true)
      expect(factory.respond_to?(:location_service)).to be(true)
      expect(factory.respond_to?(:organization_service)).to be(true)
      expect(factory.respond_to?(:patient_service)).to be(true)
      expect(factory.respond_to?(:questionnaire_service)).to be(true)
      expect(factory.respond_to?(:facilities_request)).to be(true)
      expect(factory.respond_to?(:sip_model)).to be(true)
      expect(factory.respond_to?(:transformer)).to be(true)
      expect(factory.respond_to?(:user)).to be(true)
    end
  end

  describe '.manufacture' do
    it 'returns an instance of the described class' do
      expect(described_class.manufacture(user)).to be_an_instance_of(described_class)
    end
  end

  describe '#all' do
    let(:fhir_data) { double('FHIR::Bundle', entry: [{}, {}]) }
    let(:questionnaire_response_client_reply) do
      double('FHIR::ClientReply', resource: fhir_questionnaire_response_bundle)
    end
    let(:fhir_questionnaire_response_bundle) { fhir_data }
    let(:questionnaire_client_reply) { double('FHIR::ClientReply', resource: fhir_questionnaire_bundle) }
    let(:appointments_client_reply) { double('FHIR::ClientReply', resource: fhir_data) }

    before do
      allow_any_instance_of(subject).to receive(:get_patient).and_return(client_reply)
      allow_any_instance_of(subject).to receive(:get_lighthouse_appointments).and_return(appointments_client_reply)
      allow_any_instance_of(subject).to receive(:get_locations).and_return(default_location)
      allow_any_instance_of(subject).to receive(:get_organizations).and_return(default_organization)
      allow_any_instance_of(subject).to receive(:get_facilities).and_return(default_facilities)
      allow_any_instance_of(subject).to receive(:get_save_in_progress).and_return([{}])
      allow_any_instance_of(subject)
        .to receive(:get_questionnaire_responses).and_return(questionnaire_response_client_reply)
      allow_any_instance_of(subject).to receive(:get_questionnaires).and_return(questionnaire_client_reply)
    end

    context 'when appointment does not exist' do
      let(:questionnaire_response_client_reply) { nil }
      let(:questionnaire_client_reply) { nil }
      let(:fhir_questionnaire_response_bundle) { nil }

      before do
        allow_any_instance_of(subject).to receive(:get_lighthouse_appointments).and_return(default_appointments)
        allow_any_instance_of(subject).to receive(:get_locations).and_return(nil)
      end

      it 'returns a default hash' do
        hash = { data: [] }

        expect(described_class.manufacture(user).all).to eq(hash)
      end
    end

    context 'when appointments and questionnaires and questionnaire_responses and sip and no patient' do
      let(:client_reply) { double('FHIR::ClientReply', resource: nil) }
      let(:fhir_questionnaire_bundle) { fhir_data }

      it 'returns a default hash' do
        hash = { data: [] }

        expect(described_class.manufacture(user).all).to eq(hash)
      end

      it 'has a nil patient' do
        factory = described_class.manufacture(user)
        factory.all

        expect(factory.patient).to be_nil
      end
    end

    context 'when appointments and patient and questionnaire_responses and sip and no questionnaires' do
      let(:fhir_patient) { double('FHIR::Patient') }
      let(:client_reply) { double('FHIR::ClientReply', resource: fhir_patient) }
      let(:questionnaire_client_reply) { double('FHIR::ClientReply', resource: double('FHIR::ClientReply', entry: [])) }

      it 'returns a default hash' do
        hash = { data: [] }

        expect(described_class.manufacture(user).all).to eq(hash)
      end

      it 'has a FHIR::Patient patient' do
        factory = described_class.manufacture(user)
        factory.all

        expect(factory.patient).to eq(fhir_patient)
      end
    end
  end

  describe '#get_use_context' do
    let(:locations) do
      [
        double('FHIR::Location',
               resource: double('FHIR::Bundle',
                                identifier: [double('first', value: 'vha_442_3049')],
                                to_hash: { id: 'I2-LABC' }))
      ]
    end

    it 'returns a formatted use-context string' do
      allow_any_instance_of(described_class).to receive(:locations).and_return(locations)

      expect(described_class.manufacture(user).get_use_context).to eq('venue$vha_442_3049')
    end
  end

  describe '#get_patient' do
    it 'returns a FHIR::ClientReply' do
      allow_any_instance_of(HealthQuest::Resource::Factory).to receive(:get).with(user.icn).and_return(client_reply)

      expect(described_class.manufacture(user).get_patient).to eq(client_reply)
    end
  end

  describe '#get_questionnaires' do
    let(:client_reply) { double('FHIR::ClientReply', resource: double('FHIR::Bundle', entry: [{}])) }

    it 'returns a FHIR::ClientReply' do
      allow_any_instance_of(HealthQuest::Resource::Factory).to receive(:search).with(anything).and_return(client_reply)
      allow_any_instance_of(described_class).to receive(:get_use_context).and_return('venue$vha_442_3049')

      expect(described_class.manufacture(user).get_questionnaires).to eq(client_reply)
    end
  end

  describe '#get_questionnaire_responses' do
    let(:client_reply) { double('FHIR::ClientReply', resource: double('FHIR::Bundle', entry: [{}])) }

    it 'returns a FHIR::ClientReply' do
      allow_any_instance_of(HealthQuest::Resource::Factory).to receive(:search).with(anything).and_return(client_reply)

      expect(described_class.manufacture(user).get_questionnaire_responses).to eq(client_reply)
    end
  end

  describe '#get_lighthouse_appointments' do
    let(:client_reply) { double('FHIR::ClientReply', resource: double('FHIR::Bundle', entry: [{}])) }

    it 'returns a FHIR::ClientReply' do
      allow_any_instance_of(HealthQuest::Resource::Factory).to receive(:search).with(anything).and_return(client_reply)

      expect(described_class.manufacture(user).get_lighthouse_appointments).to eq(client_reply)
    end
  end

  describe '#get_locations' do
    let(:client_reply) { double('FHIR::ClientReply', resource: double('FHIR::Bundle', entry: [{}])) }
    let(:appointments) do
      [
        double('Object',
               resource: double('FHIR::Appointment',
                                participant: [
                                  double('Object', actor: double('Reference', reference: '/foo/I2-3JYDMXC'))
                                ]))
      ]
    end
    let(:location) { double('FHIR::ClientReply', resource: double('FHIR::Bundle', entry: ['my_location'])) }

    before do
      allow_any_instance_of(subject).to receive(:lighthouse_appointments).and_return(appointments)
      allow_any_instance_of(HealthQuest::Resource::Factory).to receive(:search).with(anything).and_return(location)
    end

    it 'returns an array of locations' do
      expect(described_class.manufacture(user).get_locations).to eq(['my_location'])
    end
  end

  describe '#get_organizations' do
    let(:locations) do
      [
        double('FHIR::Location',
               resource: double('FHIR::Bundle',
                                identifier: [double('first', value: 'vha_442_3049')],
                                managingOrganization: double('Reference', reference: '/O/I2-OABC'),
                                to_hash: { id: 'I2-LABC' }))
      ]
    end
    let(:organization) { double('FHIR::ClientReply', resource: double('FHIR::Bundle', entry: ['my_org'])) }

    before do
      allow_any_instance_of(subject).to receive(:locations).and_return(locations)
      allow_any_instance_of(HealthQuest::Resource::Factory).to receive(:search)
        .with(anything).and_return(organization)
    end

    it 'returns an array of organizations' do
      expect(described_class.manufacture(user).get_organizations).to eq(['my_org'])
    end

    it 'search receives the correct set of arguments' do
      expect_any_instance_of(HealthQuest::Resource::Factory).to receive(:search)
        .with({ _id: 'I2-OABC', _count: '100' }).once

      described_class.manufacture(user).get_organizations
    end
  end

  describe '#get_facilities' do
    let(:facilities) { [] }
    let(:locations) do
      [
        double('FHIR::Location',
               resource: double('FHIR::Bundle',
                                identifier: [double('first', value: 'vha_442_3049')]))
      ]
    end
    let(:organizations) do
      [
        double('FHIR::Organization',
               resource: double('Resource',
                                identifier: [double('last', value: 'vha_442')]))
      ]
    end

    before do
      allow_any_instance_of(subject).to receive(:organizations).and_return(organizations)
      allow_any_instance_of(HealthQuest::Facilities::Request).to receive(:get).with(anything).and_return(facilities)
    end

    it 'returns an array of facilities' do
      expect(described_class.manufacture(user).get_facilities).to eq(facilities)
    end
  end

  describe '#get_save_in_progress' do
    it 'returns an empty array when user does not exist' do
      expect(described_class.manufacture(user).get_save_in_progress).to eq([])
    end
  end

  describe '#create_questionnaire_response' do
    let(:data) do
      {
        appointment: {
          id: 'abc123'
        },
        questionnaire: {
          id: 'abcd-1234',
          title: 'test'
        },
        item: []
      }
    end
    let(:client_reply) do
      double('FHIR::ClientReply', response: { code: '201' }, resource: double('Resource', id: '123abc'))
    end

    it 'returns a ClientReply' do
      allow_any_instance_of(HealthQuest::Resource::Factory).to receive(:create).with(anything).and_return(client_reply)
      allow_any_instance_of(HealthQuest::QuestionnaireResponse).to receive(:save)
        .and_return(double('HealthQuest::QuestionnaireResponse'))

      expect(described_class.new(user).create_questionnaire_response(data)).to eq(client_reply)
    end
  end

  describe '#generate_questionnaire_response_pdf' do
    let(:questionnaire_response_id) { '1bc-123-345' }

    it 'returns the id for now' do
      allow_any_instance_of(described_class).to receive(:generate_questionnaire_response_pdf)
        .with(questionnaire_response_id).and_return('')

      expect(described_class.new(user).generate_questionnaire_response_pdf(questionnaire_response_id))
        .to be_a(String)
    end
  end
end
