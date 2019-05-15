require 'test_helper'

class Workhorse::PoolTest < WorkhorseTest
  def test_idle
    with_pool 5 do |p|
      assert_equal 5, p.idle

      4.times do |_i|
        p.post do
          sleep 0.2
        end
      end

      sleep 0.1
      assert_equal 1, p.idle

      sleep 0.2
      assert_equal 5, p.idle
    end
  end

  def test_on_idle
    on_idle_calls = Concurrent::AtomicFixnum.new

    with_pool 2 do |p|
      p.on_idle { on_idle_calls.increment }

      assert_equal 0, on_idle_calls.value

      p.post { sleep 0.2 }
      p.post { sleep 0.4 }

      sleep 0.1
      assert_equal 0, on_idle_calls.value

      sleep 0.2
      assert_equal 1, on_idle_calls.value

      sleep 0.1
      assert_equal 2, on_idle_calls.value
    end
  end

  def test_overflow
    with_pool 5 do |p|
      5.times { p.post { sleep 0.2 } }

      exception = assert_raises do
        p.post { sleep 1 }
      end

      assert_equal 'All threads are busy.', exception.message
    end
  end

  def test_work
    with_pool 5 do |p|
      counter = Concurrent::AtomicFixnum.new(0)

      5.times do
        p.post do
          counter.increment
        end
      end

      sleep 0.01

      assert_equal 5, counter.value

      2.times do
        p.post do
          counter.increment
        end
      end

      sleep 0.01

      assert_equal 7, counter.value
    end
  end

  private

  def with_pool(size)
    p = Workhorse::Pool.new(size)
    begin
      yield(p)
    ensure
      p.shutdown
    end
  end
end
