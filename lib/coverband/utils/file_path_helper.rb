# frozen_string_literal: true

####
# Helper functions for shared logic related to file path manipulation
####
module Coverband
  module Utils
    module FilePathHelper
      module_function

      ###
      # Takes a full path and converts to a relative path
      ###
      def full_path_to_relative(full_path)
        RelativeFileConverter.convert(full_path)
      end
    end
  end
end
