# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationRecord do
  it 'ensures all encrypted models have the needs_kms_rotation column' do
    encrypted_models = ApplicationRecord.descendants_using_encryption
    missing = encrypted_models.reject { |model| model.column_names.include?('needs_kms_rotation') }

    expect(missing).to be_empty, lambda {
      <<~MSG
        The following models use encryption but are missing the `needs_kms_rotation` column:
        #{missing.map(&:name).join("\n")}
      MSG
    }
  end
end
