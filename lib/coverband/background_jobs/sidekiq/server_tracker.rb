module Coverband
  module BackgroundJobs
    module Sidekiq
      class ServerTracker
        def call(worker, msg, queue)
          coverband.sample do
            yield
          end
        end
      end
    end
  end
end