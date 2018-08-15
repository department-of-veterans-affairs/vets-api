# frozen_string_literal: true

class PersonalInformationLog < ActiveRecord::Base
  validates(:data, :error_class, presence: true)

  def decoded_data
    return data unless data.key?('request_body') && data.key?('response_body')
    data.merge('request_body' => Base64.decode64(data['request_body']),
               'response_body' => Base64.decode64(data['response_body']))
  end
end
