# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::SessionService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :health_quest) }

  before do
    Flipper.enable('show_healthcare_experience_questionnaire')
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
end
