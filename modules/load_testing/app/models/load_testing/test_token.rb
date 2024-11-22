module LoadTesting
  class TestToken < ApplicationRecord
    belongs_to :test_session

    validates :access_token, presence: true
    validates :refresh_token, presence: true
    validates :expires_at, presence: true

    def needs_refresh?
      expires_at < 5.minutes.from_now
    end
  end
end 