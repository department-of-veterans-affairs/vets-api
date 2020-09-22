# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
Rspec.describe OktaApplication, type: :model do
  # rubocop:enable RSpec/DescribeClass
  let(:app) do
    # only assigning the variables currently available to be sourced
    OktaApplication.new(
      {
        'id' => '123',
        'label' => 'example label',
        'permissions' => %w[read write],
        '_links' => {
          'logo' => [
            {
              'name' => 'example logo name',
              'type' => 'text/html',
              'href' => 'https://example.com/logo'
            }
          ],
          'groups' => {
            'href' => 'https://org.okta.com/api/v1/abc123/groups'
          }
        }
      }
    )
  end
  it 'parses id correctly when initializing' do
    expect(app.id).to eq('123')
  end
  it 'parses name correctly when initializing' do
    expect(app.name).to eq('example label')
  end
  it 'parses permissions correctly when initializing' do
    expect(app.permissions).to eq(%w[read write])
  end
  it 'parses logo correctly when initializing' do
    expect(app.logo_url).to eq('https://example.com/logo')
  end
end
