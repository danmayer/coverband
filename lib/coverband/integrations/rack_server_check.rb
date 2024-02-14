# frozen_string_literal: true

module Coverband
  class RackServerCheck
    def self.running?
      new(Kernel.caller_locations).running?
    end

    def initialize(stack)
      @stack = stack
    end

    def running?
      rack_server? || rails_server?
    end

    def rack_server?
      @stack.any? { |line| line.path.include?("lib/rack/") }
    end

    def rails_server?
      @stack.any? do |location|
        location.path.include?("rails/commands/commands_tasks.rb") && location.label == "server" ||
          location.path.include?("rails/commands/server/server_command.rb") && location.label == "perform"
      end
    end
  end
end
