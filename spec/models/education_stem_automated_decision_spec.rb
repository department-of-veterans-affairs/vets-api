# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationStemAutomatedDecision, type: :model do
  subject { described_class.new }

  describe 'auth_headers' do
    it 'returns nil without saved auth_headers' do
      expect(subject.auth_headers).to be_nil
    end

    it 'correctly returns hash' do
      user = create(:user)
      subject.education_benefits_claim = create(:education_benefits_claim)
      subject.auth_headers_json = EVSS::AuthHeaders.new(user).to_h.to_json
      subject.user_uuid = user.uuid
      expect(subject.auth_headers).not_to be_nil
    end
  end
end
