# frozen_string_literal: true

class Sidekiq::Batch
  attr_accessor :description
  attr_reader :bid

  def initialize(bid = nil)
    @bid = bid || SecureRandom.hex(8)
    @callbacks = []
  end

  def status
    Sidekiq::Batch::Status.new(@bid, @callbacks)
  end

  def on(*args)
    @callbacks << args
  end

  def jobs(*)
    yield
  end
end

class Sidekiq::Batch::Status
  attr_reader :bid

  def initialize(bid = SecureRandom.hex(8), callbacks = [])
    @bid = bid
    @callbacks = callbacks
  end

  def failures
    0
  end

  def join
    ::Sidekiq::Worker.drain_all

    @callbacks.each do |event, callback_class, options|
      callback_class.new.send("on_#{event}", self, options) if event != :success || failures == 0
    end
  end

  def total
    ::Sidekiq::Worker.jobs.size
  end
end
