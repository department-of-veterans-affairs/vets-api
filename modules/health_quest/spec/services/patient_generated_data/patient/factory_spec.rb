# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::Patient::Factory do
  subject { described_class }

  let(:headers) { { 'Accept' => 'application/json+fhir' } }
  let(:user) { double('User', icn: '1008596379V859838') }
  let(:session_service) { double('HealthQuest::SessionService', use: user, headers: headers) }
  let(:client_reply) { double('FHIR::ClientReply') }

  describe '#get_patient' do
    before do
      allow(HealthQuest::SessionService).to receive(:new).with(user).and_return(session_service)
    end

    describe '#get' do
      it 'returns a ClientReply' do
        allow_any_instance_of(HealthQuest::PatientGeneratedData::Patient::MapQuery)
          .to receive(:get).with(user.icn).and_return(client_reply)

        expect(subject.new(user).get).to eq(client_reply)
      end
    end

    describe '#create' do
      it 'returns a ClientReply' do
        allow_any_instance_of(HealthQuest::PatientGeneratedData::Patient::MapQuery)
          .to receive(:create).with(user).and_return(client_reply)

        expect(subject.new(user).create).to eq(client_reply)
      end
    end
  end
end
