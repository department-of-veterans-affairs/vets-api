# This is an example model. Check out the spec!
# Then delete it when you're ready to start.
class Roadrunner
  def greeting(times = 1)
    return "" unless times > 0
    ("beep beep, " * (times - 1)) + "beep beep"
  end
end
