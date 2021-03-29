require 'common/models/resource'

module VAProfile
  module Models
    class CommunicationBase < Common::Resource
      include ActiveModel::Validations
    end
  end
end
