# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsApplicationFailureMailer, type: [:mailer] do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:user_hash) do
    {
      'participant_id' => user_object.participant_id,
      'ssn' => user_object.ssn,
      'first_name' => user_object.first_name,
      'last_name' => user_object.last_name,
      'email' => user_object.email,
      'external_key' => user_object.common_name || user_object.email,
      'icn' => user_object.icn
    }
  end

  describe '#build' do
    it 'includes all info' do
      mailer = described_class.build(user_hash).deliver_now

      expect(mailer.subject).to eq("We can't process your dependents application")
      expect(mailer.to).to eq([user_object.email])
      expect(mailer.body.raw_source).to include(
        "Hello #{user_object.first_name} #{user_object.last_name}",
        'You recently submitted an application to add or remove dependents from your VA benefits (VA Form 28-686c/674)'
      )
    end
  end
end
