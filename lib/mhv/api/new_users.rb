# frozen_string_literal: true
module MHV
  module API
    module NewUsers
      def post_user_registration(attributes)
        user = MHV::User.new(attributes)
        if user.valid?
          perform(:post, '', user.mhv_attributes, {})
        else
          raise 'ValidationError'
        end
      end
    end
  end
end
