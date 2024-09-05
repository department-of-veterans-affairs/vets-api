# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/email'

describe VAProfile::Models::Email do
  it 'has valid factory' do
    expect(build(:email)).to be_valid
  end

  it 'requires an email', :aggregate_failures do
    expect(build(:email, email_address: '')).not_to be_valid
    expect(build(:email, email_address: nil)).not_to be_valid
  end

  it 'is a validly formatted email', :aggregate_failures do
    # Valid email formats
    expect(build(:email, email_address: 'john@gmail.com')).to be_valid
    expect(build(:email, email_address: '12john34@gmail.com')).to be_valid
    expect(build(:email, email_address: 'john+tom@gmail.com')).to be_valid
    expect(build(:email, email_address: 'j@example.com')).to be_valid
    expect(build(:email, email_address: 'jack@anything.io')).to be_valid
    expect(build(:email, email_address: 'jack@anything.org')).to be_valid
    expect(build(:email, email_address: 'jack@anything.net')).to be_valid
    expect(build(:email, email_address: 'jack@anything.whatever')).to be_valid

    # Invalid email formats
    expect(build(:email, email_address: 'johngmail.com')).not_to be_valid
    expect(build(:email, email_address: 'john#gmail.com')).not_to be_valid
    expect(build(:email, email_address: 'john@gmail')).not_to be_valid
    expect(build(:email, email_address: '@example.com')).not_to be_valid
  end
end
