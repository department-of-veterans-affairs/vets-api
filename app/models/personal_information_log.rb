# frozen_string_literal: true

class PersonalInformationLog < ApplicationRecord
  scope :last_week, -> { where('created_at >= :date', date: 1.week.ago) }
  validates(:data, :error_class, presence: true)

  # TODO: utility method for working with data persisted by logger middleware
  # consider removing once we have determined how we are going to analyze the data
  def decoded_data
    return data unless data.key?('request_body') && data.key?('response_body')

    data.merge('request_body' => Base64.decode64(data['request_body']),
               'response_body' => Base64.decode64(data['response_body']))
  end
end
