# frozen_string_literal: true

class DirectoryApplication < ApplicationRecord
  validate(attribute_names.reject { |attr| attr =~ /id|created_at|updated_at/i })
end
