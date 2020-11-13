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
      allow_any_instance_of(HealthQuest::PatientGeneratedData::Patient::MapQuery)
        .to receive(:get).with(user.icn).and_return(client_reply)
    end

    describe '#get_patient' do
      it 'returns a ClientReply' do
        expect(subject.new(user).get_patient).to eq(client_reply)
      end
    end
  end
end
