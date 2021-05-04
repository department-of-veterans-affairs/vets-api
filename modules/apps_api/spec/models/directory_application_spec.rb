# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DirectoryApplication, type: :model do
  it 'is invalid without valid attributes' do
    expect(DirectoryApplication.new).not_to be_valid
  end

  it 'is not valid without a name' do
    expect(DirectoryApplication.new(name: nil)).not_to be_valid
  end

  it 'is not valid without a description' do
    expect(DirectoryApplication.new(description: nil)).not_to be_valid
  end

  it 'is not valid without a service category' do
    expect(DirectoryApplication.new(service_categories: [])).not_to be_valid
  end

  it 'is not valid without a platforms' do
    expect(DirectoryApplication.new(platforms: [])).not_to be_valid
  end

  it 'is not valid without an app_url' do
    expect(DirectoryApplication.new(app_url: nil)).not_to be_valid
  end

  it 'is not valid without a tos_url' do
    expect(DirectoryApplication.new(tos_url: nil)).not_to be_valid
  end

  it 'is not valid without a privacy_url' do
    expect(DirectoryApplication.new(privacy_url: nil)).not_to be_valid
  end

  it 'is not valid without an app_type' do
    expect(DirectoryApplication.new(app_type: nil)).not_to be_valid
  end

  it 'is not valid without an logo_url' do
    expect(DirectoryApplication.new(logo_url: nil)).not_to be_valid
  end

  it 'is valid when given all necessary attributes' do
    expect(DirectoryApplication.new(
             name: 'Test Application',
             app_type: 'Third-Party-OAuth',
             app_url: 'www.example.com',
             tos_url: 'www.example.com/tos',
             privacy_url: 'www.example.com/privacy',
             service_categories: ['Health'],
             logo_url: 'www.example.com/images/logo_url',
             platforms: %w[IOS Android],
             description: ['An example application']
           )).to be_valid
  end
end
