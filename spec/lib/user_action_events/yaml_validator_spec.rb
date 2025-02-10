# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionEvents::YamlValidator do
  describe '.validate!' do
    context 'with valid config' do
      let(:config) do
        {
          'user_login' => {
            'type' => 'authentication',
            'description' => 'User logged in'
          }
        }
      end

      it 'does not raise error' do
        expect { described_class.validate!(config) }.not_to raise_error
      end
    end

    context 'with missing required key' do
      let(:config) do
        {
          'user_login' => {
            'type' => 'authentication'
          }
        }
      end

      it 'raises error' do
        expect { described_class.validate!(config) }
          .to raise_error("Missing required key 'description' for event user_login")
      end
    end

    context 'with invalid type' do
      let(:config) do
        {
          'user_login' => {
            'type' => 'invalid',
            'description' => 'User logged in'
          }
        }
      end

      it 'raises error' do
        expect { described_class.validate!(config) }
          .to raise_error(/Invalid type 'invalid' for event user_login/)
      end
    end
  end
end 