require 'rails_helper'

RSpec.describe DirectoryApplication, type: :model do
  it 'is invalid without valid attributes' do
    expect(DirectoryApplication.new).to_not be_valid
  end
  it 'is not valid without a name' do
    expect(DirectoryApplication.new(name: nil)).to_not be_valid
  end
  it 'is not valid without a description' do
    expect(DirectoryApplication.new(description: nil)).to_not be_valid
  end
  it 'is not valid without a service category' do
    expect(DirectoryApplication.new(service_categories: [])).to_not be_valid
  end
  it 'is not valid without a platforms' do
    expect(DirectoryApplication.new(platforms: [])).to_not be_valid
  end
  it 'is not valid without an app_url' do
    expect(DirectoryApplication.new(app_url: nil)).to_not be_valid
  end
  it 'is not valid without a tos_url' do
    expect(DirectoryApplication.new(tos_url: nil)).to_not be_valid
  end
  it 'is not valid without a privacy_url' do
    expect(DirectoryApplication.new(privacy_url: nil)).to_not be_valid
  end
  it 'is not valid without an app_type' do
    expect(DirectoryApplication.new(app_type: nil)).to_not be_valid
  end
  it 'is not valid without an logo_url' do
    expect(DirectoryApplication.new(logo_url: nil)).to_not be_valid
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
      platforms: ['IOS', 'Android'],
      description: ['An example application']
    )).to be_valid
  end
end
