# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::Verification, type: :model do
  let(:user_info) { create(:vye_user_info) }

  before do
    s =
      Struct.new(:settings, :scrypt_config) do
        include Vye::GenDigest
        settings =
          Config.load_files(
            Rails.root / 'config/settings.yml',
            Vye::Engine.root / 'config/settings/test.yml'
          )
        scrypt_config = extract_scrypt_config settings
        new(settings, scrypt_config)
      end

    allow_any_instance_of(Vye::GenDigest::Common)
      .to receive(:scrypt_config)
      .and_return(s.scrypt_config)
  end

  describe 'create' do
    let(:attributes) { FactoryBot.attributes_for(:vye_verification, user_info:) }

    it 'creates a record' do
      expect do
        Vye::Verification.create!(attributes)
      end.to change(Vye::Verification, :count).by(1)
    end
  end

  describe 'show todays verifications' do
    let!(:verification) { FactoryBot.create(:vye_verification, user_info:) }

    it 'shows todays verifications' do
      expect(Vye::Verification.todays_verifications.length).to eq(1)
    end

    it 'shows todays verification report' do
      expect(Vye::Verification.todays_verifications_report).to be_a(String)
    end
  end
end
