# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ConfigCertificate, type: :model do
  subject(:config_certificate) { create(:sign_in_config_certificate) }

  describe 'associations' do
    it { is_expected.to belong_to(:cert) }
    it { is_expected.to belong_to(:config) }
  end
end
