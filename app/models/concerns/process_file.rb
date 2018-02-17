# frozen_string_literal: true

module ProcessFile
  extend ActiveSupport::Concern

  included do
    after_create(:process_file)
  end
end
