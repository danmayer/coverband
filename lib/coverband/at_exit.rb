# frozen_string_literal: true

module Coverband
  class AtExit
    @semaphore = Mutex.new

    @at_exit_registered = nil
    def self.register
      return if ENV['COVERBAND_DISABLE_AT_EXIT']
      return if @at_exit_registered

      @semaphore.synchronize do
        return if @at_exit_registered

        @at_exit_registered = true
        at_exit do
          ::Coverband::Background.stop

          #####
          # TODO: This is is brittle and not a great solution to avoid deploy time
          # actions polluting the 'runtime' metrics
          #
          # * should we skip /bin/rails webpacker:compile ?
          # * Perhaps detect heroku deployment ENV var opposed to tasks?
          #####
          default_heroku_tasks = ['assets:clean', 'assets:precompile']
          if !Coverband.configuration.report_on_exit ||
             (defined?(Rake) &&
             Rake.respond_to?(:application) &&
             (Rake&.application&.top_level_tasks || []).any? { |task| default_heroku_tasks.include?(task) })
            # skip reporting
          else
            Coverband.report_coverage
            # Coverband.configuration.logger&.debug('Coverband: Reported coverage before exit')
          end
        end
      end
    end
  end
end
