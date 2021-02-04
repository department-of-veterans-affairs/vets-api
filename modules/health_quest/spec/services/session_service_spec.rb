# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::SessionService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :health_quest) }
  let(:request_id) { SecureRandom.uuid }
  let(:headers) do
    {
      'Referer' => 'https://review-instance.va.gov',
      'X-VAMF-JWT' => 'stubbed_token',
      'X-Request-ID' => request_id
    }
  end

  before do
    Flipper.enable('show_healthcare_experience_questionnaire')
    RequestStore['request_id'] = request_id
    allow_any_instance_of(HealthQuest::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe '#initialize' do
    it 'has a user attribute' do
      expect(subject.respond_to?(:user)).to eq(true)
    end

    it 'user attribute is a User' do
      expect(subject.user).to be_a(User)
    end
  end

  describe '#config' do
    it 'has a configuration' do
      expect(subject.send(:config)).to be_a(HealthQuest::Configuration)
    end
  end

  describe '#user_service' do
    it 'has a user service instance' do
      expect(subject.send(:user_service)).to be_an_instance_of(HealthQuest::UserService)
    end
  end

  describe '#headers' do
    it 'has headers' do
      expect(subject.send(:headers)).to eq(headers)
    end
  end

  describe '#perform' do
    it 'perform has a body of type Hash' do
      path = '/appointments/v1/patients/1012845331V153043/appointments/132'

      VCR.use_cassette('health_quest/appointments/get_appointment_by_id') do
        expect(subject.send(:perform, :get, path, {}, {}, {}).body).to be_a(Hash)
      end
    end
  end
end
