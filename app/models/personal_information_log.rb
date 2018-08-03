# frozen_string_literal: true

class PersonalInformationLog < ActiveRecord::Base
  validates(:data, :error_class, presence: true)
end
