# frozen_string_literal: true

Sidekiq.configure_server do |config|
  config.on(:fork) do
    Coverband.start
    Coverband.runtime_coverage!
  end
end
