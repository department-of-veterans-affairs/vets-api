# frozen_string_literal: true

def holiday?
  Holidays.on(Time.zone.today, :us, :observed).any?
end
