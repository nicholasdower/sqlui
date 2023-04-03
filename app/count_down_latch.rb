# frozen_string_literal: true

# A latch that allows you to wait for a maximum number of seconds.
class CountDownLatch
  def initialize(count)
    @count = count
    @mutex = Mutex.new
    @resource = ConditionVariable.new
  end

  def count_down
    @mutex.synchronize do
      if @count.positive?
        @count -= 1
        @resource.signal if @count.zero?
      end
      @count
    end
  end

  def count
    @mutex.synchronize { @count }
  end

  def await(timeout:)
    @mutex.synchronize do
      @resource.wait(@mutex, timeout) if @count.positive?
      raise 'timed out while waiting' unless @count.zero?
    end
  end
end
