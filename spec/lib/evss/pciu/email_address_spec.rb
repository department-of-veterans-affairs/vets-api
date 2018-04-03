# frozen_string_literal: true

require 'rails_helper'

describe EVSS::PCIU::EmailAddress do
  it 'should have valid factory' do
    expect(build(:email_address)).to be_valid
  end

  it 'should require an email', :aggregate_failures do
    expect(build(:email_address, email: '')).to_not be_valid
    expect(build(:email_address, email: nil)).to_not be_valid
  end

  it 'should be a validly formatted email', :aggregate_failures do
    # Valid email formats
    expect(build(:email_address, email: 'john@gmail.com')).to be_valid
    expect(build(:email_address, email: '12john34@gmail.com')).to be_valid
    expect(build(:email_address, email: 'j@example.com')).to be_valid
    expect(build(:email_address, email: 'jack@anything.io')).to be_valid
    expect(build(:email_address, email: 'jack@anything.org')).to be_valid
    expect(build(:email_address, email: 'jack@anything.net')).to be_valid
    expect(build(:email_address, email: 'jack@anything.whatever')).to be_valid

    # Invalid email formats
    expect(build(:email_address, email: 'johngmail.com')).to_not be_valid
    expect(build(:email_address, email: 'john#gmail.com')).to_not be_valid
    expect(build(:email_address, email: 'john@gmail')).to_not be_valid
    expect(build(:email_address, email: '@example.com')).to_not be_valid
  end
end
