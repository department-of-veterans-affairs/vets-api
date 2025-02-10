# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'UserActionEvents initializer' do
  before(:each) do
    UserActionEvent.destroy_all  # Clean between tests
  end

  before(:all) do
    Rails.application.load_seed # Ensure DB is ready
  end

  let(:yaml_config) do
    {
      'user_login' => {
        'type' => 'authentication',
        'description' => 'User logged in to the system'
      },
      'profile_update' => {
        'type' => 'profile',
        'description' => 'User updated their profile information'
      }
    }
  end

  before do
    allow(YAML).to receive(:load_file).and_return(yaml_config)
    allow(UserActionEvents::YamlValidator).to receive(:validate!).with(yaml_config)
  end

  it 'creates user action events from yaml config' do
    load Rails.root.join('config/initializers/user_action_events.rb')

    user_login = UserActionEvent.find_by(slug: 'user_login')
    expect(user_login).to have_attributes(
      event_type: 'authentication',
      details: 'User logged in to the system'
    )

    profile_update = UserActionEvent.find_by(slug: 'profile_update')
    expect(profile_update).to have_attributes(
      event_type: 'profile',
      details: 'User updated their profile information'
    )
  end

  it 'updates existing events if they already exist' do
    existing_event = create(:user_action_event,
                          slug: 'user_login',
                          event_type: 'authentication',
                          details: 'Old description')

    load Rails.root.join('config/initializers/user_action_events.rb')

    existing_event.reload
    expect(existing_event.details).to eq('Old description')
  end
end 