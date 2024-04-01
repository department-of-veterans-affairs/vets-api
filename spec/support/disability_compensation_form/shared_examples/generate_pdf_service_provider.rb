# frozen_string_literal: true

require 'rails_helper'

shared_examples 'generate pdf service provider' do
  # this is used to instantiate any Claim Service with a current_user
  subject { described_class.new(auth_headers) }

  it { is_expected.to respond_to(:generate_526_pdf) }
end
