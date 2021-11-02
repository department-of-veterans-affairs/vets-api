# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TestUserDashboard::ApplicationController, type: :controller do
  # rubocop:disable RSpec/MessageChain

  controller do
    def index; end
  end

  describe 'authenticate!' do
    subject do
      controller.authenticate!
    end

    before do
      allow_any_instance_of(described_class).to receive(:authenticated?).and_return(true)
    end

    it 'returns nil for an authenticated user' do
      expect(subject).to be_nil
    end
  end

  describe 'authenticated?' do
    subject do
      controller.authenticated?
    end

    context 'authenticated user' do
      let!(:user_details) { 'test user details' }

      before do
        Rails.env.stub(test?: false)
        allow_any_instance_of(described_class).to receive_message_chain(:warden, :authenticated?).and_return(true)
        allow_any_instance_of(described_class).to receive(:set_current_user).and_return(true)
        allow_any_instance_of(described_class).to receive(:github_user_details) { user_details }
      end

      it 'logs the authentication success message' do
        expect(Rails.logger).to receive(:info).with("TUD authentication successful: #{user_details}")
        subject
      end

      it 'returns true' do
        expect(subject).to be_truthy
      end
    end

    context 'unauthenticated user' do
      before do
        allow_any_instance_of(described_class).to receive_message_chain(:warden, :authenticated?).and_return(false)
      end

      it 'logs the authentication failure message' do
        expect(Rails.logger).to receive(:info).with('TUD authentication unsuccessful')
        subject
      end

      it 'returns false' do
        expect(subject).to be_falsey
      end
    end
  end

  describe '#authorize!' do
    subject do
      controller.authorize!
    end

    let!(:user_details) { 'test user details' }

    before do
      allow_any_instance_of(described_class).to receive(:authorized?).and_return(true)
    end

    it 'returns true' do
      expect(subject).to be_truthy
    end
  end

  describe '#authorized?' do
    subject do
      controller.authorized?
    end

    let!(:user_details) { 'test user details' }

    context 'authenticated user' do
      before do
        allow_any_instance_of(described_class).to receive(:authenticated?).and_return(true)
        allow_any_instance_of(described_class)
          .to receive_message_chain(:github_user, :organization_member?)
          .and_return(true)
        allow_any_instance_of(described_class).to receive(:github_user_details) { user_details }
      end

      it 'logs the authorization success message' do
        expect(Rails.logger).to receive(:info).with("TUD authorization successful: #{user_details}")
        subject
      end

      it 'returns true' do
        expect(subject).to be_truthy
      end
    end

    context 'unauthenticated user' do
      before do
        allow_any_instance_of(described_class).to receive(:authenticated?).and_return(false)
      end

      it 'returns false' do
        expect(subject).to be_falsey
      end
    end
  end

  describe '#github_user_details' do
    subject do
      controller.github_user_details
    end

    before do
      allow_any_instance_of(described_class).to receive_message_chain(:github_user, :id) { 1 }
      allow_any_instance_of(described_class).to receive_message_chain(:github_user, :login) { 'tedlasso' }
      allow_any_instance_of(described_class).to receive_message_chain(:github_user, :name) { 'Ted Lasso' }
      allow_any_instance_of(described_class)
        .to receive_message_chain(:github_user, :email) { 'ted.lasso@richmond.co.uk' }
    end

    it "returns a string containing the user's github information" do
      expect(subject).to eq('ID: 1, Login: tedlasso, Name: Ted Lasso, Email: ted.lasso@richmond.co.uk')
    end
  end

  # rubocop:enable RSpec/MessageChain
end
