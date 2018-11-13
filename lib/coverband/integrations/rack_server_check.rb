# frozen_string_literal: true

module Coverband
  class RackServerCheck
    def self.running?
      Kernel.caller_locations.any? { |line| line.path.include?('lib/rack/') }
    end
  end
end
