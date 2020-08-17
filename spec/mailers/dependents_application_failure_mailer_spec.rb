# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsApplicationFailureMailer, type: [:mailer] do
  include ActionView::Helpers::TranslationHelper
  let(:user) { FactoryBot.create(:evss_user, :loa3) }

  describe '#build' do
    it 'includes all info' do
      mailer = described_class.build(user).deliver_now

      expect(mailer.subject).to eq(t('dependency_claim_failuer_mailer.subject'))
      expect(mailer.to).to eq([user.email])
      expect(mailer.body.raw_source).to include(
        "Dear #{user.first_name} #{user.last_name}",
        "We're sorry. Something went wrong when we tried to submit your application to add or remove a dependent"
      )
    end
  end
end
